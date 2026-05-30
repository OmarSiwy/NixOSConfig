#!/bin/bash
# Wait a moment for outputs to be initialized
sleep 1

# Get list of connected outputs
outputs=($(riverctl list-outputs 2>/dev/null))

# Exit if no outputs detected
if [ ${#outputs[@]} -eq 0 ]; then
    echo "Warning: No outputs detected by riverctl"
    exit 0
fi

if [ ${#outputs[@]} -eq 1 ]; then
    # Single screen: show all tags
    riverctl focus-output "${outputs[0]}"
    all_tags=$(((1 << 9) - 1)) # Tags 1-9
    riverctl set-focused-tags $all_tags
elif [ ${#outputs[@]} -ge 2 ]; then
    # Two or more screens: split tags
    # Output 1 (primary): even tags (2, 4, 6, 8)
    riverctl focus-output "${outputs[0]}"
    even_tags=$((2 + 8 + 32 + 128)) # Tags 2, 4, 6, 8
    riverctl set-focused-tags $even_tags

    # Output 2 (secondary): odd tags (1, 3, 5, 7, 9)
    riverctl focus-output "${outputs[1]}"
    odd_tags=$((1 + 4 + 16 + 64 + 256)) # Tags 1, 3, 5, 7, 9
    riverctl set-focused-tags $odd_tags
fi
