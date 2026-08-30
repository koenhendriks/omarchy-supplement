#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_SOURCE="$SCRIPT_DIR/logiops/logid.cfg"
CONFIG_TARGET="/etc/logid.cfg"

if [ ! -f "$CONFIG_SOURCE" ]; then
    echo "logid config not found at $CONFIG_SOURCE"
    exit 1
fi

echo "Installing logiops"
yay -S --noconfirm --needed logiops

# Solaar was the first attempt at this and is not merely redundant now: both
# daemons open the same hidraw node and both push HID++ settings to the mouse on
# every connect, so leaving it installed means two processes fighting over the
# thumb button's diversion.
if pacman -Q solaar >/dev/null 2>&1; then
    echo "Removing solaar, which fights logid over the same device"
    sudo pacman -Rns --noconfirm solaar || echo "Could not remove solaar; remove it by hand before trusting the gestures"
fi

echo "Installing logid config into $CONFIG_TARGET"

# logid is a system daemon, so this is the one config in this repo that lands in
# /etc. Keep the first pre-existing copy and never overwrite that backup later.
if [ -f "$CONFIG_TARGET" ] && [ ! -f "$CONFIG_TARGET.bak" ] && ! cmp -s "$CONFIG_SOURCE" "$CONFIG_TARGET"; then
    echo "Backing up existing config to $CONFIG_TARGET.bak"
    sudo cp "$CONFIG_TARGET" "$CONFIG_TARGET.bak"
fi

sudo install -m 644 "$CONFIG_SOURCE" "$CONFIG_TARGET"

# enable --now starts it the first time but will not restart an already-running
# daemon, which on a re-run would leave it serving the previous config.
echo "Enabling logid"
sudo systemctl enable logid.service
sudo systemctl restart logid.service

echo "logiops setup complete!"
