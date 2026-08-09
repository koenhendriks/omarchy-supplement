#!/bin/bash

set -e

HYPRLAND_CONFIG="$HOME/.config/hypr/hyprland.conf"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OVERRIDES_DIR="$SCRIPT_DIR/hypr"

# Check if hyprland config exists
if [ ! -f "$HYPRLAND_CONFIG" ]; then
    echo "Hyprland config not found at $HYPRLAND_CONFIG"
    echo "Please install hyprland first"
    exit 1
fi

# Check if overrides directory exists
if [ ! -d "$OVERRIDES_DIR" ]; then
    echo "Overrides directory not found at $OVERRIDES_DIR"
    exit 1
fi

# Drop the source line for the retired single-file override
if grep -q "hyprland-overrides.conf" "$HYPRLAND_CONFIG"; then
    echo "Removing old hyprland-overrides.conf source line from $HYPRLAND_CONFIG"
    sed -i '/hyprland-overrides\.conf/d' "$HYPRLAND_CONFIG"
fi

shopt -s nullglob
OVERRIDE_FILES=("$OVERRIDES_DIR"/*.conf)
shopt -u nullglob

if [ ${#OVERRIDE_FILES[@]} -eq 0 ]; then
    echo "No .conf files found in $OVERRIDES_DIR"
    exit 1
fi

for override in "${OVERRIDE_FILES[@]}"; do
    SOURCE_LINE="source = $override"

    if grep -Fxq "$SOURCE_LINE" "$HYPRLAND_CONFIG"; then
        echo "Source line for $(basename "$override") already exists in $HYPRLAND_CONFIG"
    else
        echo "Adding source line for $(basename "$override") to $HYPRLAND_CONFIG"
        echo "" >> "$HYPRLAND_CONFIG"
        echo "$SOURCE_LINE" >> "$HYPRLAND_CONFIG"
    fi
done

echo "Hyprland overrides setup complete!"
