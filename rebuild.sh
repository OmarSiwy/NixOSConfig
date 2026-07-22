#!/usr/bin/env bash
# NixOS rebuild script
set -e

FLAKE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Default host matches the username in flake.nix
HOST="${1:-$(nix eval --raw ".#nixosConfigurations" --apply 'x: builtins.head (builtins.attrNames x)' 2>/dev/null || echo "user")}"

echo '🔨 Rebuilding NixOS configuration...'
echo "   Flake: $FLAKE_DIR"
echo "   Host:  $HOST"
echo ''

echo '📁 Removing old configs...'
mkdir -p ~/.config
rm -rf ~/.config/{fastfetch,ghostty,kanshi,mako,nvim,rill,river,eww,fuzzel,zathura}

echo '📋 Copying dotfiles...'
cp -r "$FLAKE_DIR"/dotfiles/* ~/.config/

echo '🧹 Cleaning caches...'
rm -rf ~/.cache/{fastfetch,ghostty,nvim,swaybg}
rm -rf ~/.local/state/{nvim,ghostty}

echo '🚀 Running nixos-rebuild...'
sudo nixos-rebuild switch --flake "$FLAKE_DIR#$HOST" "${@:2}"

echo ''
echo '✅ Rebuild complete!'
echo '💡 Restart River or press Super+Shift+R to reload'
