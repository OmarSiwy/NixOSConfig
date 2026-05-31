#!/usr/bin/env bash
echo "🔄 Reloading configurations..."
set -e

echo '📁 Removing old configs...'
rm -rf ~/.config/{fastfetch,ghostty,kanshi,rill,mako,nvim,river,rofi,waybar,xdg-desktop-portal-wlr}

echo '📋 Copying new dotfiles...'
cp -r $HOME/Documents/nixos/dotfiles/* ~/.config/

echo '🤖 Linking Claude Code skills...'
mkdir -p ~/.claude/skill-repos
rm -rf ~/.claude/skill-repos/mattpocock-skills
ln -sf $HOME/Documents/nixos/claude_skills/mattpocock-skills ~/.claude/skill-repos/mattpocock-skills
rm -rf ~/.claude/skills
bash $HOME/Documents/nixos/claude_skills/mattpocock-skills/scripts/link-skills.sh

echo '🔪 Killing running applications...'
pkill waybar || true
# NOTE: `killall awww-daemon` does NOT work on NixOS — the daemon is a wrapper
# whose comm is `.awww-daemon-wr` (truncated from `.awww-daemon-wrapped`), so
# killall's exact comm match fails. `pkill awww-daemon` works because pkill
# does a regex substring match by default.
pkill awww-daemon || true

echo '🧹 Removing state/cache...'
rm -rf ~/.cache/{fastfetch,ghostty,nvim,rofi,awww}
rm -rf ~/.local/state/{nvim,ghostty}

echo ''
if pgrep -x river >/dev/null; then
    echo "  • Restarting system services (wallpaper, waybar, etc.)..."
    bash "$HOME/.config/river/scripts/process.sh" &
    echo "    ✓ process.sh restarted"
else
    echo "  • River: Not running"
fi

echo ""
echo "✅ Reload complete!"
notify-send "Reload complete" "Press Super+Shift+R to reload rill config" --urgency=normal
