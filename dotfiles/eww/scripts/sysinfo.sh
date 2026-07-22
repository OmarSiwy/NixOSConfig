#!/usr/bin/env bash
# JSON {cpu,mem,temp} for the dashboard. Sampled over a short window for CPU%.
read -r _ a b c d _ < /proc/stat; t1=$((a+b+c+d)); i1=$d
sleep 0.3
read -r _ a b c d _ < /proc/stat; t2=$((a+b+c+d)); i2=$d
dt=$((t2-t1)); [ "$dt" -eq 0 ] && dt=1
cpu=$(( (100*(dt-(i2-i1))) / dt ))

mem=$(free -m | awk '/^Mem:/{printf "%d", $3/$2*100}')
raw=$(cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null | sort -n | tail -1)
temp=$(( ${raw:-0} / 1000 ))

jq -nc --argjson c "$cpu" --argjson m "${mem:-0}" --argjson t "$temp" \
    '{cpu:$c, mem:$m, temp:$t}'
