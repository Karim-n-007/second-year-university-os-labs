#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd -- "$(dirname -- "$0")/.." && pwd)"
log_dir="$project_dir/runtime/logs"
report_dir="$project_dir/runtime/reports"
target_date="${1:-$(date '+%Y-%m-%d')}"
report_file="$report_dir/report-$(date '+%Y%m%d-%H%M%S').txt"
log_files=()

mkdir -p "$log_dir" "$report_dir"

if [ -f "$log_dir/process-wather.log" ]; then
    log_files+=("$log_dir/process-wather.log")
fi
for file in "$log_dir"/process-wather.log.*; do
    [ -e "$file" ] || continue
    log_files+=("$file")
done

count_lines() {
    local pattern="$1"
    local count

    if [ "${#log_files[@]}" -eq 0 ]; then
        echo 0
        return 0
    fi

    count="$(grep -h "^$target_date .*${pattern}" "${log_files[@]}" 2>/dev/null | wc -l | tr -d ' ' || true)"
    if [ -z "$count" ]; then
        echo 0
    else
        echo "$count"
    fi
}

{
    echo "Process wather report"
    echo "Generated at: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "Target date: $target_date"
    echo
    echo "Counters from logs:"
    echo "- file events: $(count_lines 'EVENT source=file')"
    echo "- fifo events: $(count_lines 'EVENT source=fifo')"
    echo "- fifo commands: $(count_lines 'FIFO command=')"
    echo "- config reloads: $(count_lines 'CONFIG reloaded')"
    echo "- log rotations: $(count_lines 'LOG rotated')"
    echo "- warnings: $(count_lines '\[WARN\]')"
    echo "- service starts: $(count_lines 'SERVICE started')"
    echo "- service stops: $(count_lines 'SERVICE stopped')"
    echo
    echo "Last 15 log lines for the target date:"
    if [ "${#log_files[@]}" -eq 0 ]; then
        echo "No log files found."
    else
        grep -h "^$target_date" "${log_files[@]}" 2>/dev/null | tail -n 15 || true
    fi
} > "$report_file"

echo "Report generated: $report_file"
