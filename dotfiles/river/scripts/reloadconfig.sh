#!/usr/bin/env bash
echo "🔄 Reloading configurations..."
set -e

REPO_DIR="/home/omare/Documents/Desktop/nixos"
CONFIG_DIR="/home/omare/.config"
CACHE_DIR="/home/omare/.cache"
STATE_DIR="/home/omare/.local/state"

echo '📁 Removing old configs...'
mkdir -p "$CONFIG_DIR"
rm -rf "$CONFIG_DIR"/{fastfetch,ghostty,kanshi,rill,mako,nvim,river,rofi,waybar,xdg-desktop-portal-wlr}

echo '📋 Copying new dotfiles...'
cp -r "$REPO_DIR"/dotfiles/* "$CONFIG_DIR"/

echo '🔪 Killing running applications...'
pkill waybar || true
# NOTE: `killall awww-daemon` does NOT work on NixOS — the daemon is a wrapper
# whose comm is `.awww-daemon-wr` (truncated from `.awww-daemon-wrapped`), so
# killall's exact comm match fails. `pkill awww-daemon` works because pkill
# does a regex substring match by default.
pkill awww-daemon || true

echo '🧹 Removing state/cache...'
rm -rf "$CACHE_DIR"/{fastfetch,ghostty,nvim,rofi,awww}
rm -rf "$STATE_DIR"/{nvim,ghostty}

echo ''
if pgrep -x river >/dev/null; then
    echo "  • Restarting system services (wallpaper, waybar, etc.)..."
    bash "/home/omare/.config/river/scripts/process.sh" &
    echo "    ✓ process.sh restarted"
else
    echo "  • River: Not running"
fi

echo ""
echo "✅ Reload complete!"
notify-send "Reload complete" "Press Super+Shift+R to reload rill config" --urgency=normal
