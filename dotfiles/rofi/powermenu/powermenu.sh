#!/usr/bin/env bash

# Theme Directory
dir="$HOME/.config/rofi/powermenu"
theme="style"

# Get uptime
uptime_info="$(uptime -p | sed -e 's/up //g')"

shutdown='⏻' # Power symbol
reboot='⭮'   # Circular arrow
logout='⎋'   # Exit symbol

# Rofi Command
rofi_cmd() {
    rofi -dmenu \
        -p "Power Options" \
        -mesg "Uptime: $uptime_info" \
        -monitor -2 \
        -theme "${dir}/${theme}.rasi"
}

# Confirmation Dialog
confirm_cmd() {
    rofi -dmenu \
        -p "Are you sure?" \
        -mesg "This action cannot be undone" \
        -monitor -2 \
        -theme "${dir}/${theme}.rasi" \
        -theme-str 'window {width: 400px;}' \
        -theme-str 'mainbox {children: [ "message", "listview" ];}' \
        -theme-str 'listview {columns: 2; lines: 1; spacing: 15px;}' \
        -theme-str 'element {padding: 20px; border-radius: 8px;}' \
        -theme-str 'element-text {font: "bold 12"; horizontal-align: 0.5;}'
}

# Confirmation Function
confirm_action() {
    echo -e "Yes\nNo" | confirm_cmd
}

# Display Menu
run_rofi() {
    echo -e "$shutdown\n$reboot\n$logout" | rofi_cmd
}

# Execute Commands
execute_action() {
    selected="$(confirm_action)"
    # If user presses Escape or selects No in confirmation, just exit
    if [[ "$selected" == "Yes" ]]; then
        case $1 in
        --shutdown)
            systemctl poweroff --no-block
            ;;
        --reboot)
            systemctl reboot --no-block
            ;;
        --logout)
            loginctl terminate-session "$XDG_SESSION_ID"
            ;;
        esac
    fi
}

# Main Logic
chosen="$(run_rofi)"

# If user pressed Escape (chosen is empty), just exit without confirmation
if [[ -z "$chosen" ]]; then
    exit 0
fi

# User selected an option, show confirmation
case ${chosen} in
$shutdown)
    execute_action --shutdown
    ;;
$reboot)
    execute_action --reboot
    ;;
$logout)
    execute_action --logout
    ;;
esac
