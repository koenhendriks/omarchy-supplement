#!/bin/bash

set -e

MAKO_DIR="$HOME/.config/mako"
MAKO_CONFIG="$MAKO_DIR/config"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OVERRIDE_CONFIG="$SCRIPT_DIR/mako/config"

# Check if mako config exists
if [ ! -d "$MAKO_DIR" ]; then
    echo "Mako config not found at $MAKO_DIR"
    echo "Please install omarchy first"
    exit 1
fi

# Check if the override config exists
if [ ! -f "$OVERRIDE_CONFIG" ]; then
    echo "Override config not found at $OVERRIDE_CONFIG"
    exit 1
fi

# Omarchy ships this path as a symlink to the current theme's mako.ini, which
# `omarchy theme set` deletes and rebuilds. Our config includes that file rather
# than replacing it, so theme colours still follow the theme. Only the
# install-time theme.sh recreates this symlink, so a real file here survives
# theme switches -- mv keeps the original symlink intact as a backup.
if [ -e "$MAKO_CONFIG" ] || [ -L "$MAKO_CONFIG" ]; then
    if [ "$(readlink -f "$MAKO_CONFIG" 2>/dev/null)" != "$OVERRIDE_CONFIG" ]; then
        if [ -e "$MAKO_CONFIG.bak" ]; then
            echo "Keeping existing backup at $MAKO_CONFIG.bak"
        else
            echo "Backing up $MAKO_CONFIG to $MAKO_CONFIG.bak"
            mv "$MAKO_CONFIG" "$MAKO_CONFIG.bak"
        fi
    fi
fi

echo "Linking config to $MAKO_CONFIG"
ln -sfn "$OVERRIDE_CONFIG" "$MAKO_CONFIG"

# Pick up the new config. makoctl reload fails on a config it cannot parse, so
# this doubles as validation.
if pgrep -x mako >/dev/null; then
    echo "Reloading mako"
    makoctl reload
fi

echo "Mako config setup complete!"
