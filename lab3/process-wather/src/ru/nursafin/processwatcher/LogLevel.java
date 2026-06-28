package ru.nursafin.processwatcher;

public enum LogLevel {
    DEBUG(10),
    INFO(20),
    WARN(30),
    ERROR(40);

    private final int priority;

    LogLevel(int priority) {
        this.priority = priority;
    }

    public int priority() {
        return priority;
    }

    public static LogLevel fromString(String value) {
        if (value == null || value.isBlank()) {
            return INFO;
        }
        return switch (value.trim().toUpperCase()) {
            case "DEBUG" -> DEBUG;
            case "INFO" -> INFO;
            case "WARN", "WARNING" -> WARN;
            case "ERROR" -> ERROR;
            default -> INFO;
        };
    }
}
