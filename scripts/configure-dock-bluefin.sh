#!/usr/bin/env bash
# Configure Dash to Dock for macOS-like always-visible dock on Bluefin.
# This is separate from global-menu-for-gnome — dash-to-dock is a system extension.
set -euo pipefail

SSH_HOST="${BLUEFIN_SSH:-vm-bluefin}"
ICON_SIZE="${DOCK_ICON_SIZE:-36}"       # 75% of default 48px
MONITOR="${DOCK_MONITOR:-primary}"      # connector name or 'primary'
DOCK_POSITION="${DOCK_POSITION:-RIGHT}" # TOP, RIGHT, BOTTOM, or LEFT

if [[ "$SSH_HOST" == *"@"* ]]; then
    SSH_TARGET="$SSH_HOST"
    SSH_OPTS=(-o BatchMode=yes -o StrictHostKeyChecking=no)
elif [[ "$SSH_HOST" != "127.0.0.1" && "$SSH_HOST" != *"."* ]]; then
    SSH_TARGET="$SSH_HOST"
    SSH_OPTS=(-o BatchMode=yes -o StrictHostKeyChecking=no)
else
    SSH_KEY="${BLUEFIN_SSH_KEY:-$HOME/.ssh/vm-key}"
    SSH_PORT="${BLUEFIN_SSH_PORT:-2223}"
    SSH_USER="${BLUEFIN_SSH_USER:-martin}"
    SSH_TARGET="${SSH_USER}@127.0.0.1"
    SSH_OPTS=(-o BatchMode=yes -o StrictHostKeyChecking=no -i "$SSH_KEY" -p "$SSH_PORT")
fi

echo "==> Configuring Dash to Dock on ${SSH_TARGET}"
echo "    position: ${DOCK_POSITION}, icon size: ${ICON_SIZE}px, monitor: ${MONITOR}"

ssh "${SSH_OPTS[@]}" "$SSH_TARGET" bash -s -- "$ICON_SIZE" "$MONITOR" "$DOCK_POSITION" <<'REMOTE'
set -euo pipefail
ICON_SIZE="$1"
MONITOR="$2"
POSITION="$3"
export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus"
export GSETTINGS_SCHEMA_DIR="/usr/share/gnome-shell/extensions/dash-to-dock@micxgx.gmail.com/schemas"
SCHEMA=org.gnome.shell.extensions.dash-to-dock

gsettings set "$SCHEMA" dock-position "$POSITION"
gsettings set "$SCHEMA" autohide false
gsettings set "$SCHEMA" dock-fixed true
gsettings set "$SCHEMA" intellihide false
gsettings set "$SCHEMA" extend-height false
gsettings set "$SCHEMA" dash-max-icon-size "$ICON_SIZE"
gsettings set "$SCHEMA" preferred-monitor-by-connector "$MONITOR"
gsettings set "$SCHEMA" multi-monitor false

echo "Dash to Dock settings:"
gsettings list-recursively "$SCHEMA" | grep -E 'autohide|dock-fixed|intellihide|dash-max-icon|dock-position|preferred-monitor|extend-height'
REMOTE

echo "==> Done. Dock should stay visible on the ${DOCK_POSITION} edge of the ${MONITOR} display."
