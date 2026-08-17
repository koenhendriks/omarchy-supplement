#!/bin/bash

set -e

# Omarchy 4 (quattro) dropped satty for tensaku-edit, but the ALT + SHIFT + 4
# binding in hypr/bindings.lua still annotates with satty, so put it back.
# It is in `extra`, not the AUR.
yay -S --noconfirm --needed satty

# satty writes straight to --output-filename without creating the directory.
SCREENSHOT_DIR="$HOME/Pictures/Screenshots"

if [ ! -d "$SCREENSHOT_DIR" ]; then
    echo "Creating $SCREENSHOT_DIR"
    mkdir -p "$SCREENSHOT_DIR"
fi

echo "Satty setup complete!"
