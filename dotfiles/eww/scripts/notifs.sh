#!/usr/bin/env bash
# Parse `makoctl history` (plain-text on this mako) into a JSON array for eww.
# Each entry: {summary, app}. Newest first, capped at 8.
makoctl history 2>/dev/null | awk '
  /^Notification [0-9]+:/ {
    if (s != "") printf "%s\t%s\n", s, a
    s = $0; sub(/^Notification [0-9]+: /, "", s); a = ""
  }
  /App name:/      { x = $0; sub(/.*App name: /, "", x);      if (a == "") a = x }
  /Desktop entry:/ { x = $0; sub(/.*Desktop entry: /, "", x); if (a == "") a = x }
  END { if (s != "") printf "%s\t%s\n", s, a }
' | head -8 | jq -R -s -c '
  split("\n") | map(select(length > 0) | split("\t") | {summary: .[0], app: (.[1] // "")})
'
