#!/usr/bin/env bash
# macOS-like top bar: blur panel, centered clock, global menu polish.
set -euo pipefail

SSH_HOST="${BLUEFIN_SSH:-vm-bluefin}"

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

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "==> Deploying global-menu extension (stylesheet + menus)"
bash "$REPO_DIR/scripts/deploy-bluefin.sh"

echo "==> Applying macOS-like top bar settings on ${SSH_TARGET}"
ssh "${SSH_OPTS[@]}" "$SSH_TARGET" bash -s <<'REMOTE'
set -euo pipefail
export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus"

# Translucent blurred panel (blur-my-shell)
export GSETTINGS_SCHEMA_DIR="/usr/share/gnome-shell/extensions/blur-my-shell@aunetx/schemas"
BLUR=org.gnome.shell.extensions.blur-my-shell.panel
gsettings set "$BLUR" blur true
gsettings set "$BLUR" static-blur true
gsettings set "$BLUR" sigma 40
gsettings set "$BLUR" brightness 0.55
gsettings set "$BLUR" override-background true

# macOS-style clock: weekday + time, no seconds
gsettings set org.gnome.desktop.interface clock-show-weekday true
gsettings set org.gnome.desktop.interface clock-show-seconds false

# Global menu housekeeping
export GSETTINGS_SCHEMA_DIR="$HOME/.local/share/gnome-shell/extensions/globalmenu@ShiroOSL.github.io/schemas"
gsettings set org.gnome.shell.extensions.globalmenu debug-logging false
gsettings set org.gnome.shell.extensions.globalmenu hide-overview-button true
gsettings set org.gnome.shell.extensions.globalmenu logo-icon-size 14

# Reload extension so stylesheet applies
gnome-extensions disable globalmenu@ShiroOSL.github.io
sleep 1
gnome-extensions enable globalmenu@ShiroOSL.github.io

echo "Top bar settings applied."
REMOTE

echo "==> Done. Log out/in if the panel style does not update immediately."
