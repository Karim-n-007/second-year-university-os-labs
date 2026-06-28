package ru.nursafin.processwatcher;

import java.io.BufferedWriter;
import java.io.Closeable;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.nio.file.StandardOpenOption;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;

public final class SimpleLogger implements Closeable {
    private static final DateTimeFormatter TS = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss");
    private static final DateTimeFormatter FILE_TS = DateTimeFormatter.ofPattern("yyyyMMdd-HHmmss");

    private Path logFile;
    private BufferedWriter writer;
    private LogLevel currentLevel;

    public SimpleLogger(Path logFile, LogLevel currentLevel) throws IOException {
        this.logFile = logFile;
        this.currentLevel = currentLevel;
        openWriter();
    }

    public void setLevel(LogLevel currentLevel) {
        this.currentLevel = currentLevel;
    }

    public LogLevel getLevel() {
        return currentLevel;
    }

    public Path getLogFile() {
        return logFile;
    }

    public void switchLogFile(Path newLogFile) throws IOException {
        if (this.logFile.equals(newLogFile)) {
            return;
        }
        closeWriter();
        this.logFile = newLogFile;
        openWriter();
    }

    public Path rotate() throws IOException {
        closeWriter();
        Files.createDirectories(logFile.getParent());

        Path rotatedFile = logFile.resolveSibling(logFile.getFileName() + "." + FILE_TS.format(LocalDateTime.now()));
        if (Files.exists(logFile)) {
            Files.move(logFile, rotatedFile, StandardCopyOption.REPLACE_EXISTING);
        }
        openWriter();
        return rotatedFile;
    }

    public void debug(String category, String message) {
        log(LogLevel.DEBUG, category, message);
    }

    public void info(String category, String message) {
        log(LogLevel.INFO, category, message);
    }

    public void warn(String category, String message) {
        log(LogLevel.WARN, category, message);
    }

    public void error(String category, String message) {
        log(LogLevel.ERROR, category, message);
    }

    public void log(LogLevel level, String category, String message) {
        if (level.priority() < currentLevel.priority()) {
            return;
        }

        String line = String.format("%s [%s] [%s] %s", TS.format(LocalDateTime.now()), level, category, message);
        try {
            writer.write(line);
            writer.newLine();
            writer.flush();
        } catch (IOException ex) {
            System.err.println("LOGGER_WRITE_ERROR: " + ex.getMessage());
        }

        System.out.println(line);
    }

    private void openWriter() throws IOException {
        Files.createDirectories(logFile.getParent());
        writer = Files.newBufferedWriter(
                logFile,
                StandardCharsets.UTF_8,
                StandardOpenOption.CREATE,
                StandardOpenOption.APPEND
        );
    }

    private void closeWriter() throws IOException {
        if (writer != null) {
            writer.flush();
            writer.close();
            writer = null;
        }
    }

    @Override
    public void close() throws IOException {
        closeWriter();
    }
}
