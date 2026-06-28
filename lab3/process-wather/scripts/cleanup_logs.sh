#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd -- "$(dirname -- "$0")/.." && pwd)"
log_dir="$project_dir/runtime/logs"
retention_days="${1:-7}"

mkdir -p "$log_dir"
find "$log_dir" -maxdepth 1 -type f -name 'process-wather.log.*' -mtime "+$retention_days" -print -delete

echo "Cleanup completed. Removed rotated logs older than $retention_days day(s)."
