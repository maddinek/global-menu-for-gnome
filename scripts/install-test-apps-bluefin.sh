#!/usr/bin/env bash
# Install Cursor and Joplin on the Bluefin VM for global-menu testing.
#
# Run locally (syncs via SSH) or on the VM directly:
#   ./scripts/install-test-apps-bluefin.sh
#   ssh vm-bluefin 'bash -s' < scripts/install-test-apps-bluefin.sh
set -euo pipefail

SSH_HOST="${BLUEFIN_SSH:-}"

run_remote() {
    if [[ -n "$SSH_HOST" ]]; then
        ssh -o BatchMode=yes "$SSH_HOST" bash -s
    else
        bash -s
    fi
}

run_remote <<'REMOTE'
set -euo pipefail

echo "==> Installing Cursor (AppImage to ~/.local)"
CURSOR_DIR="$HOME/.local/share/cursor"
mkdir -p "$CURSOR_DIR" "$HOME/.local/bin" "$HOME/.local/share/applications"

DOWNLOAD_URL="$(
    curl -fsSL "https://cursor.com/api/download?platform=linux-x64&releaseTrack=stable" \
        | python3 -c "import sys, json; print(json.load(sys.stdin)['downloadUrl'])"
)"
curl -fsSL "$DOWNLOAD_URL" -o "$CURSOR_DIR/Cursor.AppImage"
chmod +x "$CURSOR_DIR/Cursor.AppImage"

cat > "$HOME/.local/bin/cursor" <<'WRAPPER'
#!/usr/bin/env bash
exec "$HOME/.local/share/cursor/Cursor.AppImage" --no-sandbox "$@"
WRAPPER
chmod +x "$HOME/.local/bin/cursor"

cat > "$HOME/.local/share/applications/cursor.desktop" <<DESKTOP
[Desktop Entry]
Name=Cursor
Comment=AI Code Editor
Exec=$HOME/.local/bin/cursor %F
Icon=cursor
Type=Application
Categories=Development;IDE;
StartupWMClass=Cursor
DESKTOP

echo "==> Installing Joplin (user flatpak: net.cozic.joplin_desktop)"
# System flathub may deny Deploy without polkit; user remote works on Bluefin.
flatpak remote-add --if-not-exists --user flathub https://dl.flathub.org/repo/flathub.flatpakrepo
flatpak install -y --user flathub net.cozic.joplin_desktop

echo "==> Installed:"
ls -lh "$CURSOR_DIR/Cursor.AppImage"
flatpak list --app --columns=application,version | grep -i joplin

echo ""
echo "Launch (requires active GNOME graphical session):"
echo "  export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/\$(id -u)/bus"
echo "  export XDG_RUNTIME_DIR=/run/user/\$(id -u)"
echo "  export WAYLAND_DISPLAY=wayland-0 DISPLAY=:0"
echo "  cursor --disable-gpu"
echo "  flatpak run --user net.cozic.joplin_desktop"
REMOTE
