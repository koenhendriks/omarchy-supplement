#!/bin/bash

set -e

HYPRLAND_CONFIG="$HOME/.config/hypr/hyprland.lua"
LEGACY_CONFIG="$HOME/.config/hypr/hyprland.conf"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OVERRIDES_DIR="$SCRIPT_DIR/hypr"

# Check if hyprland config exists
if [ ! -f "$HYPRLAND_CONFIG" ]; then
    echo "Hyprland Lua config not found at $HYPRLAND_CONFIG"
    echo "Omarchy 4 (quattro) or newer configures Hyprland in Lua; run 'omarchy update' first"
    exit 1
fi

# Check if overrides directory exists
if [ ! -d "$OVERRIDES_DIR" ]; then
    echo "Overrides directory not found at $OVERRIDES_DIR"
    exit 1
fi

# Omarchy 3 sourced .conf fragments. Quattro leaves hyprland.conf behind unread,
# but drop our lines from it so nothing loads the retired overrides twice.
if [ -f "$LEGACY_CONFIG" ] && grep -qE "hyprland-overrides\.conf|^source = $OVERRIDES_DIR/.*\.conf\$" "$LEGACY_CONFIG"; then
    echo "Removing legacy .conf source lines from $LEGACY_CONFIG"
    sed -i '/hyprland-overrides\.conf/d' "$LEGACY_CONFIG"
    sed -i "\#^source = $OVERRIDES_DIR/.*\.conf\$#d" "$LEGACY_CONFIG"
fi

shopt -s nullglob
OVERRIDE_FILES=("$OVERRIDES_DIR"/*.lua)
shopt -u nullglob

if [ ${#OVERRIDE_FILES[@]} -eq 0 ]; then
    echo "No .lua files found in $OVERRIDES_DIR"
    exit 1
fi

# dofile() rather than require(): these live outside package.path, and dofile
# re-reads the file on every `hyprctl reload` instead of serving a cached module.
for override in "${OVERRIDE_FILES[@]}"; do
    LOAD_LINE="dofile(\"$override\")"

    if grep -Fxq "$LOAD_LINE" "$HYPRLAND_CONFIG"; then
        echo "Load line for $(basename "$override") already exists in $HYPRLAND_CONFIG"
    else
        echo "Adding load line for $(basename "$override") to $HYPRLAND_CONFIG"
        echo "" >> "$HYPRLAND_CONFIG"
        echo "$LOAD_LINE" >> "$HYPRLAND_CONFIG"
    fi
done

echo "Hyprland overrides setup complete!"
