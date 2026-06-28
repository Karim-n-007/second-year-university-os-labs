package ru.nursafin.processwatcher;

public enum ProcessingMode {
    NORMAL,
    MAINTENANCE;

    public static ProcessingMode fromString(String value) {
        if (value == null || value.isBlank()) {
            return NORMAL;
        }
        return switch (value.trim().toUpperCase()) {
            case "MAINTENANCE", "MAINT", "SERVICE" -> MAINTENANCE;
            default -> NORMAL;
        };
    }

    public ProcessingMode toggled() {
        if (this == NORMAL) {
            return MAINTENANCE;
        } else {
            return NORMAL;
        }
    }
}
