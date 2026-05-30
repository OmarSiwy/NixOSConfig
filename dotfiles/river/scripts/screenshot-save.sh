#!/usr/bin/env bash
# Area screenshot to file
dir="$HOME/Pictures/Screenshots"
mkdir -p "$dir"
geometry=$(slurp) || exit 0
grim -g "$geometry" "$dir/$(date +%Y-%m-%d_%H-%M-%S).png"
notify-send Screenshot 'Area saved to Pictures/Screenshots'
