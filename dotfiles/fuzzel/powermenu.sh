#!/usr/bin/env bash
# Power menu via fuzzel --dmenu. Port of the old rofi powermenu.

cfg="$HOME/.config/fuzzel/sidebar.ini"
uptime_info="$(uptime -p | sed -e 's/up //g')"

menu() {
    printf '%s\n' \
        "⏻  Shutdown" \
        "⭮  Reboot" \
        "󰒲  Sleep" \
        "⎋  Logout"
}

confirm() {
    printf 'Yes\nNo\n' | fuzzel --dmenu --config "$cfg" --prompt "$1  "
}

chosen="$(menu | fuzzel --dmenu --config "$cfg" --prompt "Power · up ${uptime_info}  ")"
[ -z "$chosen" ] && exit 0

case "$chosen" in
    *Shutdown) [ "$(confirm 'Shutdown?')" = "Yes" ] && systemctl poweroff --no-block ;;
    *Reboot)   [ "$(confirm 'Reboot?')"   = "Yes" ] && systemctl reboot --no-block ;;
    *Sleep)    swaylock -f -c 1a1b26 ;;
    *Logout)   [ "$(confirm 'Logout?')"   = "Yes" ] && loginctl terminate-session "$XDG_SESSION_ID" ;;
esac
