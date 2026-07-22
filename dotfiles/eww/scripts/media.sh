#!/usr/bin/env bash
# deflisten source: emits JSON {status,title,artist,art} on every playerctl change.
# Album art is cached under /tmp/eww-art by artUrl hash, always as PNG: eww's
# gdk-pixbuf on NixOS ships no JPEG loader (only PNG is a builtin), so a raw
# Spotify cover (JPEG) renders blank. ImageMagick decodes it and re-emits PNG.
resolve_art() {
    url=$(playerctl metadata --format '{{mpris:artUrl}}' 2>/dev/null)
    [ -n "$url" ] || return
    d=/tmp/eww-art; mkdir -p "$d"
    out="$d/$(printf '%s' "$url" | md5sum | cut -d' ' -f1).png"
    if [ ! -s "$out" ]; then
        # Write to a per-process temp, then atomically rename. Several media.sh
        # instances can run at once (each reload spawns one); without this they
        # write the same file concurrently and eww reads a half-written PNG →
        # "IDAT: CRC error" → broken-image icon and a daemon crash.
        # png: prefix forces PNG output — magick infers format from the output
        # extension, and a ".tmp" name would otherwise pass the JPEG through.
        tmp="$out.$$.tmp"
        case "$url" in
            file://*)           magick "${url#file://}" -resize 128x128 png:"$tmp" 2>/dev/null && mv -f "$tmp" "$out" ;;
            http://*|https://*) curl -sf --max-time 5 "$url" | magick - -resize 128x128 png:"$tmp" 2>/dev/null && mv -f "$tmp" "$out" ;;
        esac
        rm -f "$tmp" 2>/dev/null
    fi
    [ -s "$out" ] && printf '%s' "$out"
}

emit() {
    status=$(playerctl status 2>/dev/null || echo "")
    if [ -z "$status" ]; then
        echo '{"status":"","title":"Nothing playing","artist":"","art":""}'
        return
    fi
    title=$(playerctl metadata --format '{{title}}' 2>/dev/null)
    artist=$(playerctl metadata --format '{{artist}}' 2>/dev/null)
    art=$(resolve_art)
    jq -nc --arg s "$status" --arg t "$title" --arg a "$artist" --arg art "$art" \
        '{status:$s, title:$t, artist:$a, art:$art}'
}

emit
playerctl --follow metadata --format '{{status}}' 2>/dev/null | while read -r _; do emit; done
