#!/bin/bash

set -e

yay -S --noconfirm --needed yaak-bin

SYSTEM_DESKTOP="/usr/share/applications/yaak.desktop"
LOCAL_DIR="$HOME/.local/share/applications"
LOCAL_DESKTOP="$LOCAL_DIR/yaak.desktop"
WEBKIT_ENV="env WEBKIT_DISABLE_DMABUF_RENDERER=1"

if [ ! -f "$SYSTEM_DESKTOP" ]; then
    echo "Desktop entry not found at $SYSTEM_DESKTOP"
    echo "Check whether yaak-bin still ships one"
    exit 1
fi

# Yaak renders blank under Wayland without this WebKitGTK workaround. The user
# entry shadows the packaged one, so it survives package upgrades -- and it is
# recopied from the package on every run to pick up any upstream changes.
mkdir -p "$LOCAL_DIR"
echo "Copying $(basename "$SYSTEM_DESKTOP") to $LOCAL_DESKTOP"
install -m 644 "$SYSTEM_DESKTOP" "$LOCAL_DESKTOP"

# The binary name is captured from whatever the entry says rather than hardcoded,
# so an upstream rename keeps working. Matching the prefix optionally makes this
# idempotent even if upstream ever ships it already prefixed.
echo "Prefixing Exec with the WebKitGTK workaround"
sed -i -E "s|^Exec=($WEBKIT_ENV )?(.*)\$|Exec=$WEBKIT_ENV \2|" "$LOCAL_DESKTOP"

if ! grep -q "^Exec=$WEBKIT_ENV " "$LOCAL_DESKTOP"; then
    echo "Failed to rewrite the Exec line in $LOCAL_DESKTOP"
    exit 1
fi

grep "^Exec=" "$LOCAL_DESKTOP"

if command -v update-desktop-database >/dev/null; then
    update-desktop-database "$LOCAL_DIR"
fi

echo "Yaak setup complete!"
