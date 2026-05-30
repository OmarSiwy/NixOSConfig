#!/usr/bin/env bash
# Area screenshot to clipboard
geometry=$(slurp) || exit 0
grim -g "$geometry" - | wl-copy -t image/png
notify-send Screenshot 'Area copied to clipboard'
