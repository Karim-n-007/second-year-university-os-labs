#!/usr/bin/env bash
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "Run this script as root."
    exit 1
fi

if ! command -v systemctl >/dev/null 2>&1; then
    echo "systemctl command is not available on this host."
    exit 1
fi

project_dir="$(cd -- "$(dirname -- "$0")/.." && pwd)"
template="$project_dir/systemd/process-wather.service.template"
target_unit="/etc/systemd/system/process-wather.service"
env_file="$project_dir/config/process-wather.env"
service_name="process-wather.service"
watcher_user="${WATCHER_USER:-${SUDO_USER:-root}}"
watcher_group="${WATCHER_GROUP:-$(id -gn "$watcher_user")}" 

if [ ! -f "$template" ]; then
    echo "Template file was not found: $template"
    exit 1
fi

mkdir -p /etc/systemd/system
mkdir -p "$(dirname -- "$env_file")"

cat > "$env_file" <<ENV
WATCHER_CONFIG=$project_dir/config/watcher.properties
JAVA_OPTS=
ENV

sed \
    -e "s|__PROJECT_DIR__|$project_dir|g" \
    -e "s|__ENV_FILE__|$env_file|g" \
    -e "s|__WATCHER_USER__|$watcher_user|g" \
    -e "s|__WATCHER_GROUP__|$watcher_group|g" \
    "$template" > "$target_unit"

systemctl daemon-reload
systemctl enable --now "$service_name"

echo "System-level unit installed: $target_unit"
echo "User: $watcher_user"
echo "Group: $watcher_group"
echo "Useful commands:"
echo "systemctl status $service_name"
echo "systemctl reload $service_name"
echo "journalctl -u $service_name -f"
