#!/usr/bin/env bash
echo "🔄 Reloading configurations..."
set -e

REPO_DIR="/home/omare/Documents/Desktop/nixos"
CONFIG_DIR="/home/omare/.config"
CACHE_DIR="/home/omare/.cache"
STATE_DIR="/home/omare/.local/state"

echo '📁 Removing old configs...'
mkdir -p "$CONFIG_DIR"
rm -rf "$CONFIG_DIR"/{fastfetch,ghostty,kanshi,mako,nvim,eww,fuzzel,zathura,xdg-desktop-portal-wlr}

echo '📋 Copying new dotfiles...'
cp -r "$REPO_DIR"/dotfiles/* "$CONFIG_DIR"/

echo '🔪 Killing running applications...'
# eww is NOT killed here — process.sh handles the full eww lifecycle via
# `eww kill` (proper IPC shutdown + socket cleanup). A raw `pkill eww` leaves
# the IPC socket at /run/user/*/eww-server_* stale, which blocks `eww daemon`.
pkill awww-daemon || true

echo '🧹 Removing state/cache...'
rm -rf "$CACHE_DIR"/{fastfetch,ghostty,nvim,awww}
rm -rf "$STATE_DIR"/{nvim,ghostty}
rm -rf /tmp/eww-art   # album-art PNG cache; drop it so a stale/bad cover can't wedge eww

echo ''
if pgrep -x river >/dev/null; then
    echo "  • Restarting system services (wallpaper, eww, etc.)..."
    setsid bash "/home/omare/.config/river/scripts/process.sh" &
    echo "    ✓ process.sh restarted"
else
    echo "  • River: Not running"
fi

echo ""
echo "✅ Reload complete!"
notify-send "Reload complete" "Press Super+Shift+R to reload rill config" --urgency=normal
