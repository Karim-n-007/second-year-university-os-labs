#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd -- "$(dirname -- "$0")/.." && pwd)"
config_file="${WATCHER_CONFIG:-$project_dir/config/watcher.properties}"
config_dir="$(cd -- "$(dirname -- "$config_file")" && pwd)"

read_config_value() {
    local key="$1"
    local current_key
    local current_value
    local value=""

    while IFS='=' read -r current_key current_value; do
        [ "$current_key" = "$key" ] || continue
        value="$current_value"
    done < "$config_file"

    [ -n "$value" ] || return 1

    if [[ "$value" = /* ]]; then
        printf '%s\n' "$value"
    else
        printf '%s/%s\n' "$config_dir" "$value"
    fi
}

pid_file="$(read_config_value pid.file)"
status_file="$(read_config_value status.file)"
log_file="$(read_config_value log.file)"

running_pid() {
    local pid

    [ -f "$pid_file" ] || return 1
    pid="$(tr -d '[:space:]' < "$pid_file")"
    [ -n "$pid" ] || return 1
    kill -0 "$pid" 2>/dev/null || return 1
    printf '%s\n' "$pid"
}

start_service() {
    local pid

    if pid="$(running_pid)"; then
        echo "Process wather is already running. PID=$pid"
        return 1
    fi

    mkdir -p "$(dirname -- "$log_file")"
    if command -v setsid >/dev/null 2>&1; then
        setsid "$project_dir/scripts/run_foreground.sh" </dev/null >/dev/null 2>&1 &
    else
        nohup "$project_dir/scripts/run_foreground.sh" </dev/null >/dev/null 2>&1 &
    fi

    for _ in $(seq 1 40); do
        sleep 0.5
        if pid="$(running_pid)"; then
            echo "Process wather started. PID=$pid"
            return 0
        fi
    done

    echo "Failed to start process wather. Last log lines:"
    if [ -f "$log_file" ]; then
        tail -n 20 "$log_file"
    else
        echo "Log file does not exist yet: $log_file"
    fi
    return 1
}

stop_service() {
    local pid

    if ! pid="$(running_pid)"; then
        echo "Process wather is not running."
        rm -f "$pid_file"
        return 0
    fi

    kill -TERM "$pid"
    for _ in $(seq 1 40); do
        sleep 0.5
        if ! kill -0 "$pid" 2>/dev/null; then
            rm -f "$pid_file"
            echo "Process wather stopped gracefully."
            return 0
        fi
    done

    echo "Graceful stop timed out. Sending SIGKILL."
    kill -KILL "$pid" 2>/dev/null || true
    rm -f "$pid_file"
    echo "Process wather stopped forcibly."
}

status_service() {
    local pid

    if pid="$(running_pid)"; then
        echo "Process wather is running. PID=$pid"
        if [ -f "$status_file" ]; then
            echo
            cat "$status_file"
        fi
        return 0
    fi

    echo "Process wather is not running."
    if [ -f "$status_file" ]; then
        echo
        echo "Last saved status snapshot:"
        cat "$status_file"
    fi
    return 1
}

cmd="${1:-}"

if [ "$cmd" = "start" ]; then
    start_service
elif [ "$cmd" = "stop" ]; then
    stop_service
elif [ "$cmd" = "restart" ]; then
    stop_service || true
    start_service
elif [ "$cmd" = "status" ]; then
    status_service
else
    echo "Usage: $0 {start|stop|restart|status}"
    exit 1
fi
