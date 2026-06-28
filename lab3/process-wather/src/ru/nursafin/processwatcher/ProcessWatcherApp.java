package ru.nursafin.processwatcher;

import java.nio.file.Files;
import java.nio.file.Path;

public final class ProcessWatcherApp {
    private ProcessWatcherApp() {
    }

    public static void main(String[] args) {
        try {
            Path configPath = parseConfigPath(args);
            WatcherConfig config = WatcherConfig.load(configPath);
            WatcherService service = new WatcherService(config);
            service.run();
        } catch (Exception ex) {
            System.err.println("WATHER_START_FAILED: " + ex.getMessage());
            ex.printStackTrace(System.err);
            System.exit(1);
        }
    }

    private static Path parseConfigPath(String[] args) throws Exception {
        Path defaultPath = Path.of("config", "watcher.properties").toAbsolutePath().normalize();

        for (int i = 0; i < args.length; i++) {
            if ("--help".equals(args[i]) || "-h".equals(args[i])) {
                printHelp();
                System.exit(0);
            }
            if ("--config".equals(args[i])) {
                if (i + 1 >= args.length) {
                    throw new IllegalArgumentException("--config requires a path value");
                }
                Path explicit = Path.of(args[i + 1]).toAbsolutePath().normalize();
                ensureExists(explicit);
                return explicit;
            }
        }

        ensureExists(defaultPath);
        return defaultPath;
    }

    private static void ensureExists(Path path) {
        if (!Files.exists(path)) {
            throw new IllegalArgumentException("Configuration file does not exist: " + path);
        }
    }

    private static void printHelp() {
        System.out.println("Usage: java -jar process-wather.jar [--config /absolute/path/to/watcher.properties]");
    }
}
