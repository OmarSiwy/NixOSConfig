#!/usr/bin/env bash

# ═══════════════════════════════════════════
# DISPLAY LAYOUT (kanshi)
# ═══════════════════════════════════════════
# Runs first so monitor geometry is set before waybar/wallpaper start.
# Profiles live in ~/.config/kanshi/config
killall kanshi 2>/dev/null || true
kanshi &
# Give kanshi a moment to apply the active profile before dependents start.
sleep 0.2

# ═══════════════════════════════════════════
# SIDE BAR - EWW (Tokyo Night bar on the right edge; replaces waybar)
# ═══════════════════════════════════════════
# `eww kill`, not `killall eww`: on NixOS the daemon's comm is `.eww-wrapped`
# (same wrapper gotcha as awww-daemon below), so killall's exact match no-ops
# and leaves a stale daemon with the old config running.
eww kill 2>/dev/null || true
rm -f /run/user/"$(id -u)"/eww-server_* 2>/dev/null
sleep 0.2
# `eww daemon` daemonizes and only returns once its IPC socket is ready, so no
# `&`/sleep race: backgrounding it meant `eww open` could fire before the socket
# existed, spawn a second competing daemon, and silently drop the windows.
eww daemon
# One dock per connected output — eww has no "all monitors" flag, so we open a
# uniquely-id'd instance per screen index (--screen overrides :monitor).
nout=$(wlr-randr 2>/dev/null | grep -cE '^[^ ]'); [ "${nout:-0}" -ge 1 ] || nout=1
for i in $(seq 0 $((nout - 1))); do
  eww open dock --id "dock-$i" --screen "$i"
done

# ═══════════════════════════════════════════
# AUDIO SERVER
# ═══════════════════════════════════════════
if [[ ! $(pgrep wireplumber) ]]; then
    wireplumber &
fi

# ═══════════════════════════════════════════
# WALLPAPER (runs in background — independent of everything else)
# ═══════════════════════════════════════════
{
# NixOS note: `awww-daemon` is a wrapper — the actual process comm is
# `.awww-daemon-wr` (truncated `.awww-daemon-wrapped`), so `killall awww-daemon`
# silently no-ops (exact comm match fails). `pkill awww-daemon` works because
# by default it does regex substring match on comm and "awww-daemon" is a
# substring of ".awww-daemon-wr".
pkill awww-daemon 2>/dev/null || true
# Wait until the compositor actually has at least one output before spawning
# awww-daemon — otherwise the daemon comes up, sees zero outputs, and never
# renders a wallpaper even after outputs arrive.
for i in $(seq 1 50); do
    if wlr-randr 2>/dev/null | grep -q '^[^ ]'; then
        break
    fi
    sleep 0.1
done
awww-daemon &
# Wait until the daemon has registered at least one output (non-empty query),
# not just for the socket to be listening.
for i in $(seq 1 50); do
    if [[ -n "$(awww query 2>/dev/null)" ]]; then
        break
    fi
    sleep 0.1
done
bash $HOME/.config/river/scripts/wallpaper.sh
} &

# ═══════════════════════════════════════════
# TOUCHPAD
# ═══════════════════════════════════════════
# riverctl input is gone in river 0.4.1.
# rill handles input configuration internally via its config.zon.

# ═══════════════════════════════════════════
# BRIGHTNESS
# ═══════════════════════════════════════════
# Nothing to do at startup: the kernel restores the panel's last level, and
# brightnessctl (rill keybinds + the eww slider) drives it from there.
# There used to be a `light -S $(light -G)` here — `light` isn't installed, so
# it only ever printed "command not found" into the session log.

# ═══════════════════════════════════════════
# SYSTEM TRAY & APPLETS
# ═══════════════════════════════════════════
# Started here, not via programs.nm-applet: that module hangs off
# graphical-session.target, which this river session never activates.
# --indicator = StatusNotifierItem, the only kind eww's systray shows.
pkill -x nm-applet 2>/dev/null || true
nm-applet --indicator &

# Clipboard persistence for Wayland selections copied via wl-copy
killall wl-clip-persist 2>/dev/null || true
wl-clip-persist --clipboard regular &

# ═══════════════════════════════════════════
# NOTIFICATIONS
# ═══════════════════════════════════════════
# Notification daemon - reload config instead of restarting
# (mako auto-starts via dbus when needed)
makoctl reload 2>/dev/null || mako &

# ═══════════════════════════════════════════
# IDLE / DPMS
# ═══════════════════════════════════════════
killall swayidle 2>/dev/null || true
swayidle -w \
  timeout 600  'swaylock -f -c 1a1b26' \
  before-sleep 'swaylock -f -c 1a1b26' &

# ═══════════════════════════════════════════
# STARTUP COMPLETE
# ═══════════════════════════════════════════
notify-send 'River WM' 'Load complete!' --urgency=low
