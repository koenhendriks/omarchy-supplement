#!/bin/bash

set -e

RULES="/etc/udev/rules.d/40-streamdeck.rules"

# The AUR's opendeck-bin was removed once Arch packaged OpenDeck in extra. The two
# own the same files without declaring a conflict, so pacman stops on file
# conflicts instead of replacing one with the other. Removing it first is safe:
# pacman -R only deletes the package's own files, never OpenDeck's data under ~.
if pacman -Q opendeck-bin >/dev/null 2>&1; then
    echo "Removing opendeck-bin, which the extra package replaces"
    sudo pacman -R --noconfirm opendeck-bin
fi

echo "Installing opendeck"
omarchy-pkg-add opendeck

if [ ! -f "$RULES" ]; then
    echo "Stream Deck udev rules not found at $RULES"
    echo "Check whether opendeck still ships them"
    exit 1
fi

# The rules land in /etc/udev/rules.d, which systemd's pacman udev-reload hook
# does not watch -- it only covers /usr/lib/udev/rules.d. Without this reload the
# device stays root-owned until a replug or reboot, and OpenDeck sees no Stream
# Deck at all.
echo "Reloading udev rules for $RULES"
sudo udevadm control --reload-rules
sudo udevadm trigger --subsystem-match=usb --subsystem-match=hidraw

echo "OpenDeck setup complete!"
