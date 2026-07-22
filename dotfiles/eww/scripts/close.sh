#!/usr/bin/env bash
# Debounced panel close: wait out the slide animation, then close only if the
# cursor really left both the strip and the panel (avoids hover flicker).
sleep 0.25
[ "$(eww get dock_hover 2>/dev/null)" = "false" ] && eww close panel
