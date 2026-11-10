#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/omarchy-plugin.sh"

OMASNAP_CONFIG_DIR="$HOME/.config/omasnap"

if ! command -v omasnap >/dev/null 2>&1; then
    echo "omasnap not found on PATH"
    echo "Omarchy 4.5 or newer ships it; run 'omarchy update' first"
    exit 1
fi

# omasnap reads its config on every launch, so nothing needs restarting.
mkdir -p "$OMASNAP_CONFIG_DIR"
install_if_changed "$SCRIPT_DIR/omasnap/omasnap.conf" "$OMASNAP_CONFIG_DIR/omasnap.conf" 644

echo "Omasnap setup complete!"
