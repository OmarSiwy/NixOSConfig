#!/usr/bin/env bash

# ═══════════════════════════════════════════
# CONFIGURATION
# ═══════════════════════════════════════════
WALLPAPER_DIR="$HOME/Pictures/wallpapers"
CURRENT_WALL_FILE="/tmp/currentwall"
FALLBACK_COLOR="#1a1b26"

# ═══════════════════════════════════════════
# CHECK IF WALLPAPER DIRECTORY EXISTS
# ═══════════════════════════════════════════
if [[ ! -d "$WALLPAPER_DIR" ]]; then
    echo "Wallpaper directory not found: $WALLPAPER_DIR"
    echo "Creating directory and using fallback color..."
    mkdir -p "$WALLPAPER_DIR"

    # Use solid color fallback
    awww clear "$FALLBACK_COLOR"
    exit 0
fi

# ═══════════════════════════════════════════
# FIND WALLPAPERS
# ═══════════════════════════════════════════
# Count available wallpapers
wallpaper_count=$(find "$WALLPAPER_DIR" -type f \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.jpeg" \) 2>/dev/null | wc -l)

if [[ $wallpaper_count -eq 0 ]]; then
    echo "No wallpapers found in $WALLPAPER_DIR"
    echo "Using solid color fallback: $FALLBACK_COLOR"

    # Use solid color fallback
    awww clear "$FALLBACK_COLOR"
    exit 0
fi

echo "Found $wallpaper_count wallpaper(s) in $WALLPAPER_DIR"

# ═══════════════════════════════════════════
# SELECT A WALLPAPER
# ═══════════════════════════════════════════
if [[ -f "$CURRENT_WALL_FILE" ]] && [[ -s "$CURRENT_WALL_FILE" ]]; then
    current_wall=$(cat "$CURRENT_WALL_FILE")
    echo "Current wallpaper: $current_wall"

    # Find a different wallpaper than the current one
    image=$(find "$WALLPAPER_DIR" -type f \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.jpeg" \) 2>/dev/null |
        grep -v "$current_wall" |
        shuf | head -n 1)

    # If we only have one wallpaper, use it anyway
    if [[ -z "$image" ]]; then
        image=$(find "$WALLPAPER_DIR" -type f \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.jpeg" \) 2>/dev/null |
            shuf | head -n 1)
    fi
else
    # No current wallpaper tracked, pick random one
    image=$(find "$WALLPAPER_DIR" -type f \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.jpeg" \) 2>/dev/null |
        shuf | head -n 1)
fi

# ═══════════════════════════════════════════
# VERIFY IMAGE EXISTS
# ═══════════════════════════════════════════
if [[ -z "$image" ]] || [[ ! -f "$image" ]]; then
    echo "ERROR: Could not find a valid wallpaper!"
    echo "Using solid color fallback: $FALLBACK_COLOR"

    # Use solid color fallback
    awww clear "$FALLBACK_COLOR"
    exit 0
fi

echo "Selected wallpaper: $image"

# ═══════════════════════════════════════════
# SET WALLPAPER
# ═══════════════════════════════════════════
# Save current wallpaper to file
echo "$image" >"$CURRENT_WALL_FILE"

# Set wallpaper via awww (daemon already running from process.sh)
awww img "$image" --resize crop --transition-type none

echo "Wallpaper set successfully!"
