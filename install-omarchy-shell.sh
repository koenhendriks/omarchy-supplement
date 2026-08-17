#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BAR_FRAGMENT="$SCRIPT_DIR/omarchy/shell-bar.json"
SHELL_CONFIG="$HOME/.config/omarchy/shell.json"
SHELL_DEFAULT="/usr/share/omarchy/config/omarchy/shell.json"

if [ ! -f "$BAR_FRAGMENT" ]; then
    echo "Bar layout fragment not found at $BAR_FRAGMENT"
    exit 1
fi

if [ ! -f "$SHELL_DEFAULT" ]; then
    echo "Omarchy shell defaults not found at $SHELL_DEFAULT"
    echo "Omarchy 4 (quattro) or newer is required; run 'omarchy update' first"
    exit 1
fi

if [ ! -d "$(dirname "$SHELL_CONFIG")" ]; then
    echo "Omarchy config directory not found at $(dirname "$SHELL_CONFIG")"
    exit 1
fi

# Merge rather than overwrite. shell.json also holds idle timings and plugin
# registrations, and the bar writes to it directly when widgets are dragged
# around, so only the keys in the fragment are replaced.
#
# A copy rather than a symlink into this repo, deliberately: omarchy-refresh-config
# installs defaults with `cp -f`, which follows a symlink and would overwrite the
# file here instead of the one in ~/.config.
MERGED="$(mktemp)"

python3 - "$BAR_FRAGMENT" "$SHELL_CONFIG" "$SHELL_DEFAULT" "$MERGED" <<'PY'
import json
import sys

fragment_path, config_path, default_path, out_path = sys.argv[1:5]

with open(fragment_path) as handle:
    fragment = json.load(handle)

# No user file yet means the shell is running off the packaged defaults.
try:
    with open(config_path) as handle:
        config = json.load(handle)
except FileNotFoundError:
    with open(default_path) as handle:
        config = json.load(handle)

config.setdefault("version", 1)
config.setdefault("bar", {})
config["bar"].update(fragment)

with open(out_path, "w") as handle:
    json.dump(config, handle, indent=2, ensure_ascii=False, sort_keys=True)
    handle.write("\n")
PY

if cmp -s "$MERGED" "$SHELL_CONFIG"; then
    echo "shell.json bar layout already up to date"
    rm -f "$MERGED"
else
    if [ -f "$SHELL_CONFIG" ] && [ ! -e "$SHELL_CONFIG.bak" ]; then
        echo "Backing up $SHELL_CONFIG to $SHELL_CONFIG.bak"
        cp "$SHELL_CONFIG" "$SHELL_CONFIG.bak"
    fi

    echo "Writing bar layout to $SHELL_CONFIG"
    cat "$MERGED" >"$SHELL_CONFIG"
    rm -f "$MERGED"

    # The shell hot-reloads shell.json on save, so no restart is needed.
    echo "Bar layout applied (shell.json hot-reloads)"
fi

echo "Omarchy shell setup complete!"
