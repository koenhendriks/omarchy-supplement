#!/bin/bash

set -e

yay -S --noconfirm --needed wifiman-desktop

LOCAL_DIR="$HOME/.local/share/applications"
WEBKIT_ENV="env WEBKIT_DISABLE_DMABUF_RENDERER=1"

# The entry is found by asking the package what it installed rather than
# hardcoding a filename, so an upstream rename does not silently skip the fix.
SYSTEM_DESKTOP="$(pacman -Qlq wifiman-desktop 2>/dev/null |
    grep -E '^/usr/share/applications/.*\.desktop$' | head -1)"

if [ -z "$SYSTEM_DESKTOP" ] || [ ! -f "$SYSTEM_DESKTOP" ]; then
    echo "No desktop entry found under /usr/share/applications for wifiman-desktop"
    echo "Check whether the package still ships one"
    exit 1
fi

LOCAL_DESKTOP="$LOCAL_DIR/$(basename "$SYSTEM_DESKTOP")"

# WifiMan is WebKitGTK (the PKGBUILD depends on webkit2gtk-4.1), so it hits the
# same Wayland bug as Yaak: the window renders blank without the DMA-BUF renderer
# disabled. Same treatment -- a user entry shadowing the packaged one, recopied
# from the package on every run so upstream changes to the entry are picked up.
mkdir -p "$LOCAL_DIR"
echo "Copying $(basename "$SYSTEM_DESKTOP") to $LOCAL_DESKTOP"
install -m 644 "$SYSTEM_DESKTOP" "$LOCAL_DESKTOP"

# Every Exec line, not just the first: WifiMan's entry may carry desktop actions
# with their own Exec, and an action launched without the workaround renders just
# as blank as the main window. Matching the prefix optionally keeps this
# idempotent, and works if upstream ever ships it already prefixed.
echo "Prefixing Exec with the WebKitGTK workaround"
sed -i -E "s|^Exec=($WEBKIT_ENV )?(.*)\$|Exec=$WEBKIT_ENV \2|" "$LOCAL_DESKTOP"

if ! grep -q "^Exec=$WEBKIT_ENV " "$LOCAL_DESKTOP"; then
    echo "Failed to rewrite the Exec line in $LOCAL_DESKTOP"
    exit 1
fi

grep -E "^Exec=" "$LOCAL_DESKTOP"

if command -v update-desktop-database >/dev/null; then
    update-desktop-database "$LOCAL_DIR"
fi

echo "WifiMan setup complete!"
