#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BAR_FRAGMENT="$SCRIPT_DIR/omarchy/shell-bar.json"
BAR_SCRIPTS_SRC="$SCRIPT_DIR/omarchy/bar"
BAR_SCRIPTS_DIR="$HOME/.config/omarchy/bar/scripts"
LOCAL_BIN="$HOME/.local/bin"
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

install_bar_script() {
    local src="$1"
    local target="$2"

    if cmp -s "$src" "$target"; then
        echo "$(basename "$src") already up to date in $(dirname "$target")"
    else
        echo "Installing $(basename "$src") to $(dirname "$target")"
        install -m 755 "$src" "$target"
    fi
}

# Scripts the bar's `type: "command"` modules exec, installed where shell.json
# points at them. Copies rather than symlinks, for the same omarchy-refresh-config
# reason as below.
if [ -d "$BAR_SCRIPTS_SRC" ]; then
    mkdir -p "$BAR_SCRIPTS_DIR"
    for script in "$BAR_SCRIPTS_SRC"/*; do
        [ -f "$script" ] || continue
        install_bar_script "$script" "$BAR_SCRIPTS_DIR/$(basename "$script")"
    done
fi

# The VPN toggle is worth having outside the bar -- a Stream Deck key, a
# keybinding, a script -- so it goes on PATH as `vpn` too. A second copy rather
# than a symlink into ~/.config: anything calling it from PATH should not break
# when the bar's script directory is rebuilt or reset, and both copies are
# written from this one source on every run, so they cannot drift.
if [ -f "$BAR_SCRIPTS_SRC/vpn" ]; then
    mkdir -p "$LOCAL_BIN"
    install_bar_script "$BAR_SCRIPTS_SRC/vpn" "$LOCAL_BIN/vpn"
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
import getpass
import json
import os
import sys

fragment_path, config_path, default_path, out_path = sys.argv[1:5]

# Widget ids for cloned plugins are per-user (<user>.clock), so the fragment
# spells them "@user@.clock" and the placeholder is filled in here. That keeps the
# checked-in layout free of one particular username.
user = os.environ.get("USER") or getpass.getuser()

with open(fragment_path) as handle:
    fragment = json.loads(handle.read().replace("@user@", user))

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
