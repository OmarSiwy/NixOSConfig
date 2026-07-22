#!/usr/bin/env bash
# JSON of toggle/indicator state. Host facts: battery BAT1, wifi via nmcli.
vol=$(pamixer --get-volume 2>/dev/null || echo 0)
[ "$(pamixer --get-mute 2>/dev/null)" = "true" ] && muted=true || muted=false

bcap=$(cat /sys/class/power_supply/BAT1/capacity 2>/dev/null || echo 0)
bstat=$(cat /sys/class/power_supply/BAT1/status 2>/dev/null || echo Unknown)
case "$bstat" in Charging|Full) charging=true ;; *) charging=false ;; esac

ssid=$(nmcli -t -f NAME connection show --active 2>/dev/null | grep -viE '^(lo|tailscale)' | head -1)
net=${ssid:-Disconnected}

if bluetoothctl show 2>/dev/null | grep -q "Powered: yes"; then
    bluetoothctl devices Connected 2>/dev/null | grep -q . && bt=connected || bt=on
else
    bt=off
fi

makoctl mode 2>/dev/null | grep -q do-not-disturb && dnd=true || dnd=false

jq -nc \
    --argjson vol "$vol" --argjson muted "$muted" \
    --argjson bcap "$bcap" --argjson charging "$charging" \
    --arg net "$net" --arg bt "$bt" --argjson dnd "$dnd" \
    '{vol:$vol, muted:$muted, bcap:$bcap, charging:$charging, net:$net, bt:$bt, dnd:$dnd}'
