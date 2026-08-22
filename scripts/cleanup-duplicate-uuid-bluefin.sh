#!/usr/bin/env bash
# Leave exactly one copy of the extension installed on the Bluefin VM.
#
# Debugging GNOME 50 needed a throwaway UUID, because a Wayland session never
# re-imports an extension's JavaScript: the only way to load fixed code without
# logging out is to install it under a name the shell has not seen yet. That
# leaves two directories behind, and at the next login both would try to own
# the panel.
#
# Run this and then log out. The switch cannot take effect in the running
# session (the old UUID still has the crashing module cached), so the menus
# stay on the throwaway copy until the shell restarts.
set -euo pipefail

SSH_HOST="${BLUEFIN_SSH:-vm-bluefin}"
SSH_OPTS=(-o BatchMode=yes -o StrictHostKeyChecking=no)

if [[ "$SSH_HOST" == *"@"* ]]; then
    SSH_TARGET="$SSH_HOST"
elif [[ "$SSH_HOST" != "127.0.0.1" && "$SSH_HOST" != *"."* ]]; then
    SSH_TARGET="$SSH_HOST"
else
    SSH_KEY="${BLUEFIN_SSH_KEY:-$HOME/.ssh/vm-key}"
    SSH_PORT="${BLUEFIN_SSH_PORT:-2223}"
    SSH_USER="${BLUEFIN_SSH_USER:-martin}"
    SSH_TARGET="${SSH_USER}@127.0.0.1"
    SSH_OPTS+=(-i "$SSH_KEY" -p "$SSH_PORT")
fi

KEEP_UUID="${KEEP_UUID:-globalmenu@ShiroOSL.github.io}"
DROP_UUID="${DROP_UUID:-globalmenu-fixed@maddinek.local}"

echo "==> Keeping ${KEEP_UUID}, removing ${DROP_UUID} on ${SSH_TARGET}"

ssh "${SSH_OPTS[@]}" "$SSH_TARGET" bash -s -- "$KEEP_UUID" "$DROP_UUID" <<'REMOTE'
set -euo pipefail
KEEP_UUID="$1"
DROP_UUID="$2"
export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus"
EXT_DIR="$HOME/.local/share/gnome-shell/extensions"

if [[ ! -f "$EXT_DIR/$KEEP_UUID/menuManager.js" ]]; then
    echo "ERROR: $KEEP_UUID is not installed; run deploy-bluefin.sh first." >&2
    exit 1
fi

python3 - "$KEEP_UUID" "$DROP_UUID" <<'PY'
import ast, subprocess, sys

keep, drop = sys.argv[1], sys.argv[2]
raw = subprocess.check_output(
    ['gsettings', 'get', 'org.gnome.shell', 'enabled-extensions'], text=True)
enabled = [uuid for uuid in ast.literal_eval(raw) if uuid != drop]
if keep not in enabled:
    enabled.append(keep)

# GVariant array literal; UUIDs never contain quotes.
literal = '[' + ', '.join(f"'{uuid}'" for uuid in enabled) + ']'
subprocess.check_call(
    ['gsettings', 'set', 'org.gnome.shell', 'enabled-extensions', literal])
print('enabled-extensions ->', literal)
PY

rm -rf "$EXT_DIR/$DROP_UUID"
echo "Removed $EXT_DIR/$DROP_UUID"
ls -1 "$EXT_DIR" | grep -i globalmenu || true
REMOTE

echo
echo "==> Done. Log out and back in; only ${KEEP_UUID} will load."
