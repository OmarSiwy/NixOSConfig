#!/usr/bin/env bash
# Area screenshot to clipboard
geometry=$(slurp) || exit 0
error_file=/tmp/screenshot-clip.err
rm -f "$error_file"

if grim -g "$geometry" - | wl-copy-rs --type image/png 2>"$error_file"; then
    notify-send Screenshot 'Area copied to clipboard'
    rm -f "$error_file"
    exit 0
fi

notify-send Screenshot "Failed to copy area: $(tr '\n' ' ' < "$error_file" | sed 's/[[:space:]]\\+/ /g')"
exit 1
