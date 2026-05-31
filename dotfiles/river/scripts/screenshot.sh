#!/usr/bin/env bash
# Area screenshot to clipboard
geometry=$(slurp) || exit 0
grim -g "$geometry" /tmp/screenshot-clip.png || exit 1
nohup wl-copy -t image/png < /tmp/screenshot-clip.png &>/dev/null &
disown
notify-send Screenshot 'Area copied to clipboard'
