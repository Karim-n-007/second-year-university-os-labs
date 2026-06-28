package ru.nursafin.processwatcher;

import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Properties;

public final class WatcherConfig {
    private final Path configFile;
    private final Path inputFile;
    private final Path logFile;
    private final Path fifoPath;
    private final Path pidFile;
    private final Path statusFile;
    private final Path reportDir;
    private final int pollIntervalMs;
    private final LogLevel logLevel;
    private final ProcessingMode processingMode;

    private WatcherConfig(
            Path configFile,
            Path inputFile,
            Path logFile,
            Path fifoPath,
            Path pidFile,
            Path statusFile,
            Path reportDir,
            int pollIntervalMs,
            LogLevel logLevel,
            ProcessingMode processingMode) {
        this.configFile = configFile;
        this.inputFile = inputFile;
        this.logFile = logFile;
        this.fifoPath = fifoPath;
        this.pidFile = pidFile;
        this.statusFile = statusFile;
        this.reportDir = reportDir;
        this.pollIntervalMs = pollIntervalMs;
        this.logLevel = logLevel;
        this.processingMode = processingMode;
    }

    public static WatcherConfig load(Path configFile) throws IOException {
        Properties props = new Properties();
        try (InputStream in = Files.newInputStream(configFile)) {
            props.load(in);
        }

        Path baseDir = configFile.toAbsolutePath().normalize().getParent();

        return new WatcherConfig(
                configFile.toAbsolutePath().normalize(),
                resolvePath(baseDir, props.getProperty("input.file", "../runtime/input/events.txt")),
                resolvePath(baseDir, props.getProperty("log.file", "../runtime/logs/watcher.log")),
                resolvePath(baseDir, props.getProperty("fifo.path", "../runtime/ipc/watcher.fifo")),
                resolvePath(baseDir, props.getProperty("pid.file", "../runtime/run/watcher.pid")),
                resolvePath(baseDir, props.getProperty("status.file", "../runtime/run/status.txt")),
                resolvePath(baseDir, props.getProperty("report.dir", "../runtime/reports")),
                parsePollInterval(props.getProperty("poll.interval.ms", "0")),
                LogLevel.fromString(props.getProperty("log.level", "INFO")),
                ProcessingMode.fromString(props.getProperty("processing.mode", "NORMAL"))
        );
    }

    private static int parsePollInterval(String value) {
        try {
            int parsed = Integer.parseInt(value.trim());
            return Math.max(parsed, 0);
        } catch (Exception ex) {
            return 0;
        }
    }

    private static Path resolvePath(Path baseDir, String rawValue) {
        Path candidate = Path.of(rawValue.trim());
        if (candidate.isAbsolute()) {
            return candidate.normalize();
        }
        return baseDir.resolve(candidate).normalize();
    }

    public Path configFile() {
        return configFile;
    }

    public Path inputFile() {
        return inputFile;
    }

    public Path logFile() {
        return logFile;
    }

    public Path fifoPath() {
        return fifoPath;
    }

    public Path pidFile() {
        return pidFile;
    }

    public Path statusFile() {
        return statusFile;
    }

    public Path reportDir() {
        return reportDir;
    }

    public int pollIntervalMs() {
        return pollIntervalMs;
    }

    public LogLevel logLevel() {
        return logLevel;
    }

    public ProcessingMode processingMode() {
        return processingMode;
    }
}
