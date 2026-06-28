#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd -- "$(dirname -- "$0")/.." && pwd)"
cron_log="$project_dir/runtime/logs/cron.log"
generated_file="$project_dir/cron/process-wather.crontab.generated"
tmp_file="$(mktemp)"

if ! command -v crontab >/dev/null 2>&1; then
    echo "crontab command is not available on this host."
    exit 1
fi

mkdir -p "$project_dir/runtime/logs" "$project_dir/cron"

cat > "$generated_file" <<CRON
# BEGIN PROCESS WATHER CRON
5 0 * * * $project_dir/scripts/generate_report.sh >> $cron_log 2>&1
15 0 * * * $project_dir/scripts/cleanup_logs.sh 7 >> $cron_log 2>&1
# END PROCESS WATHER CRON
CRON

{
    crontab -l 2>/dev/null | sed '/# BEGIN PROCESS WATHER CRON/,/# END PROCESS WATHER CRON/d' || true
    cat "$generated_file"
} > "$tmp_file"

crontab "$tmp_file"
rm -f "$tmp_file"

echo "Cron entries installed."
echo "Generated crontab block: $generated_file"
