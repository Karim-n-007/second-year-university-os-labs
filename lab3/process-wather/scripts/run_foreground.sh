#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd -- "$(dirname -- "$0")/.." && pwd)"
env_file="$project_dir/config/process-wather.env"
default_config="$project_dir/config/watcher.properties"
jar_file="$project_dir/build/process-wather.jar"

if [ -f "$env_file" ]; then
    source "$env_file"
fi

watcher_config="${WATCHER_CONFIG:-$default_config}"
java_opts=()
if [ -n "${JAVA_OPTS:-}" ]; then
    read -r -a java_opts <<< "$JAVA_OPTS"
fi

if [ ! -f "$jar_file" ] || find "$project_dir/src" -type f -newer "$jar_file" | grep -q .; then
    "$project_dir/scripts/build.sh"
fi

mkdir -p \
    "$project_dir/runtime/input" \
    "$project_dir/runtime/ipc" \
    "$project_dir/runtime/logs" \
    "$project_dir/runtime/reports" \
    "$project_dir/runtime/run"

exec java "${java_opts[@]}" -jar "$jar_file" --config "$watcher_config"
