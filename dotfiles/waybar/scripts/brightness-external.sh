#!/usr/bin/env bash
# Control brightness of an external DDC/CI-capable monitor.
#
# Fast path: caches the I2C bus number in /tmp so subsequent calls skip
# the bus-scan that makes plain `ddcutil` slow (~1-2 s per call).
# With --bus N + --sleep-multiplier 0.1, a write typically completes in
# ~100-200 ms which is fast enough for scroll-wheel use.

set -uo pipefail

STEP=5
CACHE=/tmp/waybar-brightness-bus
LOCK=/tmp/waybar-brightness.lock

# Resolve the I2C bus number once, then cache it.
# Skips "Invalid display" entries (e.g. the laptop's internal eDP-1 panel)
# and returns the bus number for the first valid external display.
get_bus() {
  if [[ -f "$CACHE" ]]; then
    cat "$CACHE"
    return
  fi
  local bus
  bus=$(ddcutil detect 2>/dev/null \
    | awk '/^Display [0-9]/{found=1}
           found && /I2C bus/{match($0,/i2c-([0-9]+)/,a); print a[1]; exit}')
  if [[ -n "$bus" ]]; then
    echo "$bus" > "$CACHE"
    echo "$bus"
  fi
}

# Shared options: target the cached bus, skip readback, reduce sleep delays.
ddc_opts() {
  local bus
  bus=$(get_bus)
  if [[ -n "$bus" ]]; then
    echo "--bus $bus --noverify --sleep-multiplier 0.1"
  else
    echo "--noverify --sleep-multiplier 0.1"
  fi
}

case "${1:-status}" in
  up)
    flock -n "$LOCK" ddcutil $(ddc_opts) setvcp 10 + "$STEP" >/dev/null 2>&1 || true
    ;;
  down)
    flock -n "$LOCK" ddcutil $(ddc_opts) setvcp 10 - "$STEP" >/dev/null 2>&1 || true
    ;;
  status)
    val=$(flock -n "$LOCK" timeout 5 ddcutil $(ddc_opts) getvcp 10 -t 2>/dev/null | awk '{print $4}')
    if [[ -z "${val:-}" ]]; then
      printf '{"text":"󰃞  --","tooltip":"External brightness unavailable","class":"error"}\n'
    else
      printf '{"text":"󰃞  %s%%","tooltip":"External brightness: %s%%","class":""}\n' "$val" "$val"
    fi
    ;;
  reset-cache)
    rm -f "$CACHE"
    echo "Bus cache cleared."
    ;;
  *)
    echo "usage: $0 {up|down|status|reset-cache}" >&2
    exit 2
    ;;
esac
