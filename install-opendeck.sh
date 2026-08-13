#!/bin/bash

set -e

RULES="/etc/udev/rules.d/40-streamdeck.rules"

echo "Installing opendeck-bin"
yay -S --noconfirm --needed opendeck-bin

if [ ! -f "$RULES" ]; then
    echo "Stream Deck udev rules not found at $RULES"
    echo "Check whether opendeck-bin still ships them"
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
