#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd -- "$(dirname -- "$0")/.." && pwd)"
pid_file="$project_dir/runtime/run/process-wather.pid"
fifo_file="$project_dir/runtime/ipc/process-wather.fifo"
input_file="$project_dir/runtime/input/events.txt"

"$project_dir/scripts/build.sh"
"$project_dir/scripts/watcherctl.sh" stop >/dev/null 2>&1 || true
mkdir -p "$(dirname -- "$input_file")"
: > "$input_file"

"$project_dir/scripts/watcherctl.sh" start
sleep 2

printf 'line-from-file-1\nline-from-file-2\n' >> "$input_file"
sleep 2

printf 'hello from fifo\nSTATUS\nCHANGE_MODE\nCMD:UNKNOWN\n' > "$fifo_file"
sleep 2

kill -USR1 "$(cat "$pid_file")"
sleep 1
kill -HUP "$(cat "$pid_file")"
sleep 1
kill -USR2 "$(cat "$pid_file")"
sleep 2

"$project_dir/scripts/generate_report.sh"
"$project_dir/scripts/watcherctl.sh" status || true
"$project_dir/scripts/watcherctl.sh" stop

echo
echo "Self-check finished. Review:"
echo "$project_dir/runtime/logs/process-wather.log"
echo "$project_dir/runtime/reports"
