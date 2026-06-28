package ru.nursafin.processwatcher;

import sun.misc.Signal;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardOpenOption;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.Locale;

public final class WatcherService {
    private static final DateTimeFormatter STATUS_TS = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss");
    private static final int MAX_FIFO_MESSAGES_PER_ITERATION = 20;
    private static final double FIFO_READ_TIMEOUT_SECONDS = 0.05;
    private static final int UNIX_FILE_TYPE_MASK = 0170000;
    private static final int UNIX_FIFO_TYPE = 0010000;

    private boolean stopRequested;
    private boolean reloadRequested;
    private boolean statusRequested;
    private boolean rotateRequested;

    private WatcherConfig config;
    private SimpleLogger logger;
    private ProcessingMode currentMode;
    private Instant startedAt;
    private Instant lastEventAt;

    private String stopReason = "normal_exit";
    private int knownLineCount;
    private long warningCount;
    private long reloadCount;
    private long rotateCount;
    private long fileEventCount;
    private long fifoEventCount;
    private long fifoCommandCount;

    private boolean running;
    private boolean cleanupExecuted;

    public WatcherService(WatcherConfig config) {
        this.config = config;
        this.currentMode = config.processingMode();
    }

    public void run() throws Exception {
        prepareFilesystem();
        logger = new SimpleLogger(config.logFile(), config.logLevel());
        startedAt = Instant.now();
        lastEventAt = startedAt;

        acquirePidFile();
        registerSignals();

        logger.info("SERVICE", "SERVICE started pid=" + currentPid()
                + " mode=" + currentMode
                + " inputFile=" + config.inputFile()
                + " fifoPath=" + config.fifoPath()
                + " pollIntervalMs=" + config.pollIntervalMs()
                + " logLevel=" + config.logLevel());

        knownLineCount = countLines(config.inputFile());
        logger.info("SOURCE", "SOURCE file watcher initialized knownLineCount=" + knownLineCount
                + " file=" + config.inputFile());
        logger.info("FIFO", "FIFO polling initialized path=" + config.fifoPath());

        writeStatusFile("startup");
        running = true;

        while (running) {
            applyRequestedOperations();
            processAppendedFileLines();
            processFifoMessages();
            writeStatusFile("loop");
        }

        cleanup("main_loop_exit");
    }

    private void prepareFilesystem() throws Exception {
        createParent(config.inputFile());
        createParent(config.logFile());
        createParent(config.fifoPath());
        createParent(config.pidFile());
        createParent(config.statusFile());
        Files.createDirectories(config.reportDir());

        if (Files.notExists(config.inputFile())) {
            Files.writeString(config.inputFile(), "", StandardCharsets.UTF_8,
                    StandardOpenOption.CREATE, StandardOpenOption.WRITE);
        }

        ensureFifoExists(config.fifoPath());
    }

    private void createParent(Path file) throws IOException {
        if (file.getParent() != null) {
            Files.createDirectories(file.getParent());
        }
    }

    private void ensureFifoExists(Path fifoPath) throws Exception {
        if (Files.exists(fifoPath)) {
            if (!isNamedPipe(fifoPath)) {
                throw new IOException("Path already exists and is not a FIFO: " + fifoPath);
            }
            return;
        }

        Process process = new ProcessBuilder("mkfifo", fifoPath.toString()).start();
        int exitCode = process.waitFor();
        if (exitCode != 0 || !Files.exists(fifoPath) || !isNamedPipe(fifoPath)) {
            throw new IOException("Failed to create FIFO at " + fifoPath + ". Exit code=" + exitCode);
        }
    }

    private boolean isNamedPipe(Path path) {
        try {
            Object raw = Files.getAttribute(path, "unix:mode");
            int mode = ((Number) raw).intValue();
            return (mode & UNIX_FILE_TYPE_MASK) == UNIX_FIFO_TYPE;
        } catch (Exception ex) {
            return false;
        }
    }

    private void acquirePidFile() throws IOException {
        long pid = currentPid();
        Path pidFile = config.pidFile();

        if (Files.exists(pidFile)) {
            String raw = Files.readString(pidFile, StandardCharsets.UTF_8).trim();
            if (!raw.isBlank()) {
                try {
                    long existingPid = Long.parseLong(raw);
                    boolean alive = ProcessHandle.of(existingPid).map(ProcessHandle::isAlive).orElse(false);
                    if (alive && existingPid != pid) {
                        throw new IOException("Watcher is already running with PID " + existingPid);
                    }
                } catch (NumberFormatException ignored) {
                }
            }
        }

        Files.writeString(pidFile, Long.toString(pid), StandardCharsets.UTF_8,
                StandardOpenOption.CREATE, StandardOpenOption.TRUNCATE_EXISTING, StandardOpenOption.WRITE);
    }

    private void registerSignals() {
        handleSignal("TERM", () -> requestStop("signal_TERM"));
        handleSignal("INT", () -> requestStop("signal_INT"));
        handleSignal("HUP", this::requestReload);
        handleSignal("USR1", this::requestStatusSnapshot);
        handleSignal("USR2", this::requestLogRotation);
    }

    private void handleSignal(String signalName, Runnable action) {
        try {
            Signal.handle(new Signal(signalName), ignored -> action.run());
        } catch (Throwable ex) {
            if (logger != null) {
                logger.warn("SIGNAL", "Signal " + signalName + " is not available in this JVM: " + ex.getMessage());
            }
        }
    }

    private void requestStop(String reason) {
        stopReason = reason;
        stopRequested = true;
        if (logger != null) {
            logger.info("SIGNAL", "SIGNAL stop requested reason=" + reason);
        }
    }

    private void requestReload() {
        reloadRequested = true;
        if (logger != null) {
            logger.info("SIGNAL", "SIGNAL name=HUP action=request_reload");
        }
    }

    private void requestStatusSnapshot() {
        statusRequested = true;
        if (logger != null) {
            logger.info("SIGNAL", "SIGNAL name=USR1 action=request_status_snapshot");
        }
    }

    private void requestLogRotation() {
        rotateRequested = true;
        if (logger != null) {
            logger.info("SIGNAL", "SIGNAL name=USR2 action=request_log_rotation");
        }
    }

    private void applyRequestedOperations() {
        if (reloadRequested) {
            reloadRequested = false;
            reloadConfiguration();
        }
        if (statusRequested) {
            statusRequested = false;
            logStatusSnapshot("signal_USR1");
        }
        if (rotateRequested) {
            rotateRequested = false;
            rotateLogFile();
        }
        if (stopRequested) {
            running = false;
        }
    }

    private void reloadConfiguration() {
        try {
            WatcherConfig newConfig = WatcherConfig.load(config.configFile());
            Path oldFifo = config.fifoPath();
            Path oldInput = config.inputFile();
            Path oldLog = config.logFile();
            ProcessingMode oldMode = currentMode;
            int oldPoll = config.pollIntervalMs();
            LogLevel oldLevel = config.logLevel();

            if (!oldLog.equals(newConfig.logFile())) {
                logger.switchLogFile(newConfig.logFile());
                logger.info("CONFIG", "CONFIG log file changed old=" + oldLog + " new=" + newConfig.logFile());
            }

            logger.setLevel(newConfig.logLevel());
            currentMode = newConfig.processingMode();

            if (!oldInput.equals(newConfig.inputFile())) {
                createParent(newConfig.inputFile());
                if (Files.notExists(newConfig.inputFile())) {
                    Files.writeString(newConfig.inputFile(), "", StandardCharsets.UTF_8,
                            StandardOpenOption.CREATE, StandardOpenOption.WRITE);
                }
                knownLineCount = countLines(newConfig.inputFile());
                logger.info("CONFIG", "CONFIG input file changed old=" + oldInput
                        + " new=" + newConfig.inputFile()
                        + " startFromLine=" + knownLineCount);
            }

            if (!oldFifo.equals(newConfig.fifoPath())) {
                createParent(newConfig.fifoPath());
                ensureFifoExists(newConfig.fifoPath());
                logger.info("CONFIG", "CONFIG fifo path changed old=" + oldFifo + " new=" + newConfig.fifoPath());
            }

            config = newConfig;
            reloadCount++;
            logger.info("CONFIG", "CONFIG reloaded oldPollIntervalMs=" + oldPoll
                    + " newPollIntervalMs=" + config.pollIntervalMs()
                    + " oldLogLevel=" + oldLevel
                    + " newLogLevel=" + config.logLevel()
                    + " oldMode=" + oldMode
                    + " newMode=" + currentMode);
        } catch (Exception ex) {
            warningCount++;
            logger.error("CONFIG", "CONFIG reload failed: " + ex.getMessage());
        }
    }

    private void rotateLogFile() {
        try {
            Path rotated = logger.rotate();
            rotateCount++;
            logger.info("LOG", "LOG rotated archive=" + rotated + " active=" + logger.getLogFile());
        } catch (IOException ex) {
            warningCount++;
            logger.error("LOG", "LOG rotation failed: " + ex.getMessage());
        }
    }

    private void processAppendedFileLines() {
        try {
            List<String> lines = Files.readAllLines(config.inputFile(), StandardCharsets.UTF_8);
            if (lines.size() < knownLineCount) {
                logger.warn("SOURCE", "SOURCE file was truncated or replaced, resetting cursor oldLineCount="
                        + knownLineCount + " newLineCount=" + lines.size());
                warningCount++;
                knownLineCount = 0;
            }

            for (int index = knownLineCount; index < lines.size(); index++) {
                String line = lines.get(index);
                if (line == null || line.isBlank()) {
                    warningCount++;
                    logger.warn("EVENT", "Ignored empty line in source file lineNumber=" + (index + 1));
                    continue;
                }
                fileEventCount++;
                lastEventAt = Instant.now();
                logger.info("EVENT", "EVENT source=file lineNumber=" + (index + 1)
                        + " text=\"" + escape(line) + "\"");
            }

            knownLineCount = lines.size();
        } catch (IOException ex) {
            warningCount++;
            logger.error("SOURCE", "Failed to read source file: " + ex.getMessage());
        }
    }

    private void processFifoMessages() {
        for (int i = 0; i < MAX_FIFO_MESSAGES_PER_ITERATION; i++) {
            String message = tryReadSingleFifoMessage();
            if (message == null) {
                return;
            }
            handleFifoMessage(message);
            if (!running) {
                return;
            }
        }
    }

    private String tryReadSingleFifoMessage() {
        try {
            Process process = new ProcessBuilder(
                    "bash",
                    "-lc",
                    "fifo=\"$1\"; exec 3<> \"$fifo\"; if IFS= read -r -t " + FIFO_READ_TIMEOUT_SECONDS + " line <&3; then printf '%s' \"$line\"; fi",
                    "bash",
                    config.fifoPath().toString()
            ).start();

            String output;
            try (BufferedReader stdout = new BufferedReader(new InputStreamReader(process.getInputStream(), StandardCharsets.UTF_8));
                 BufferedReader stderr = new BufferedReader(new InputStreamReader(process.getErrorStream(), StandardCharsets.UTF_8))) {
                output = stdout.readLine();
                String err = stderr.readLine();
                int exitCode = process.waitFor();
                if (exitCode != 0 && err != null && !err.isBlank()) {
                    warningCount++;
                    logger.warn("FIFO", "FIFO poll warning: " + err.trim());
                }
            }

            if (output == null) {
                return null;
            }

            String trimmed = output.trim();
            return trimmed.isEmpty() ? "" : trimmed;
        } catch (Exception ex) {
            warningCount++;
            logger.error("FIFO", "FIFO poll failed: " + ex.getMessage());
            return null;
        }
    }

    private void handleFifoMessage(String message) {
        if (message.isEmpty()) {
            warningCount++;
            logger.warn("FIFO", "Ignored empty FIFO message");
            return;
        }

        String upper = message.toUpperCase(Locale.ROOT);
        switch (upper) {
            case "STATUS", "CMD:STATUS" -> {
                fifoCommandCount++;
                logger.info("FIFO", "FIFO command=STATUS action=status_snapshot");
                logStatusSnapshot("fifo_STATUS");
            }
            case "STOP", "CMD:STOP" -> {
                fifoCommandCount++;
                logger.info("FIFO", "FIFO command=STOP action=request_stop");
                requestStop("fifo_STOP");
            }
            case "MODE_CHANGE", "CMD:MODE_CHANGE", "CHANGE_MODE", "CMD:CHANGE_MODE" -> {
                fifoCommandCount++;
                ProcessingMode oldMode = currentMode;
                currentMode = currentMode.toggled();
                logger.info("MODE", "MODE changed trigger=fifo oldMode=" + oldMode + " newMode=" + currentMode);
            }
            default -> {
                if (upper.startsWith("CMD:")) {
                    fifoCommandCount++;
                    warningCount++;
                    logger.warn("FIFO", "Unknown FIFO command message=\"" + escape(message) + "\"");
                } else {
                    fifoEventCount++;
                    lastEventAt = Instant.now();
                    logger.info("EVENT", "EVENT source=fifo text=\"" + escape(message) + "\"");
                }
            }
        }
    }

    private void logStatusSnapshot(String reason) {
        String snapshot = buildStatusSnapshot(reason).replace(System.lineSeparator(), " | ");
        logger.info("STATUS", "STATUS snapshot " + snapshot);
        writeStatusFile(reason);
    }

    private void writeStatusFile(String reason) {
        try {
            createParent(config.statusFile());
            Files.writeString(
                    config.statusFile(),
                    buildStatusSnapshot(reason),
                    StandardCharsets.UTF_8,
                    StandardOpenOption.CREATE,
                    StandardOpenOption.TRUNCATE_EXISTING,
                    StandardOpenOption.WRITE
            );
        } catch (IOException ex) {
            if (logger != null) {
                warningCount++;
                logger.error("STATUS", "Failed to write status file: " + ex.getMessage());
            }
        }
    }

    private String buildStatusSnapshot(String reason) {
        Instant now = Instant.now();
        Duration uptime = Duration.between(startedAt, now);
        long totalHandled = fileEventCount + fifoEventCount + fifoCommandCount;

        return "reason=" + reason + System.lineSeparator()
                + "timestamp=" + STATUS_TS.format(LocalDateTime.now()) + System.lineSeparator()
                + "pid=" + currentPid() + System.lineSeparator()
                + "mode=" + currentMode + System.lineSeparator()
                + "uptimeSeconds=" + uptime.getSeconds() + System.lineSeparator()
                + "inputFile=" + config.inputFile() + System.lineSeparator()
                + "fifoPath=" + config.fifoPath() + System.lineSeparator()
                + "logFile=" + logger.getLogFile() + System.lineSeparator()
                + "pollIntervalMs=" + config.pollIntervalMs() + System.lineSeparator()
                + "logLevel=" + logger.getLevel() + System.lineSeparator()
                + "knownLineCount=" + knownLineCount + System.lineSeparator()
                + "fileEventCount=" + fileEventCount + System.lineSeparator()
                + "fifoEventCount=" + fifoEventCount + System.lineSeparator()
                + "fifoCommandCount=" + fifoCommandCount + System.lineSeparator()
                + "warningCount=" + warningCount + System.lineSeparator()
                + "reloadCount=" + reloadCount + System.lineSeparator()
                + "rotateCount=" + rotateCount + System.lineSeparator()
                + "totalHandledMessages=" + totalHandled + System.lineSeparator()
                + "lastEventAt=" + STATUS_TS.format(LocalDateTime.ofInstant(lastEventAt, ZoneId.systemDefault()))
                + System.lineSeparator();
    }

    private void cleanup(String caller) {
        if (cleanupExecuted) {
            return;
        }
        cleanupExecuted = true;

        try {
            if (Files.exists(config.pidFile())) {
                String rawPid = Files.readString(config.pidFile(), StandardCharsets.UTF_8).trim();
                if (rawPid.equals(Long.toString(currentPid()))) {
                    Files.deleteIfExists(config.pidFile());
                }
            }
        } catch (Exception ex) {
            if (logger != null) {
                logger.warn("SERVICE", "Failed to delete PID file: " + ex.getMessage());
            }
        }

        if (logger != null) {
            logger.info("SERVICE", "SERVICE stopped caller=" + caller
                    + " reason=" + stopReason
                    + " fileEventCount=" + fileEventCount
                    + " fifoEventCount=" + fifoEventCount
                    + " fifoCommandCount=" + fifoCommandCount
                    + " warningCount=" + warningCount
                    + " reloadCount=" + reloadCount
                    + " rotateCount=" + rotateCount);
            writeStatusFile("shutdown");
            try {
                logger.close();
            } catch (IOException ignored) {
            }
        }
    }

    private static int countLines(Path file) throws IOException {
        if (Files.notExists(file)) {
            return 0;
        }
        return Files.readAllLines(file, StandardCharsets.UTF_8).size();
    }

    private static String escape(String text) {
        return text.replace("\\", "\\\\").replace("\"", "\\\"");
    }

    private static long currentPid() {
        return ProcessHandle.current().pid();
    }
}
