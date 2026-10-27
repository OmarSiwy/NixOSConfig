#!/usr/bin/env bash
# JSON of toggle/indicator state. Host fact: battery BAT1.
vol=$(pamixer --get-volume 2>/dev/null || echo 0)
[ "$(pamixer --get-mute 2>/dev/null)" = "true" ] && muted=true || muted=false

bcap=$(cat /sys/class/power_supply/BAT1/capacity 2>/dev/null || echo 0)
bstat=$(cat /sys/class/power_supply/BAT1/status 2>/dev/null || echo Unknown)
case "$bstat" in Charging|Full) charging=true ;; *) charging=false ;; esac

jq -nc \
    --argjson vol "$vol" --argjson muted "$muted" \
    --argjson bcap "$bcap" --argjson charging "$charging" \
    '{vol:$vol, muted:$muted, bcap:$bcap, charging:$charging}'
