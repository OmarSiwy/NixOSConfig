#!/usr/bin/env bash
# Clear notifications. mako has no "clear history" command and its history is
# in-memory, so we dismiss the active ones and restart mako to wipe history.
makoctl dismiss --all 2>/dev/null
pkill mako 2>/dev/null
sleep 0.3
setsid -f mako >/dev/null 2>&1
