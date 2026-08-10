#!/bin/bash

set -e

WAYBAR_DIR="$HOME/.config/waybar"
WAYBAR_CONFIG="$WAYBAR_DIR/config.jsonc"
WAYBAR_STYLE="$WAYBAR_DIR/style.css"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OVERRIDE_CONFIG="$SCRIPT_DIR/waybar/config.jsonc"
OVERRIDE_STYLE="$SCRIPT_DIR/waybar/style.css"
OVERRIDE_SCRIPTS="$SCRIPT_DIR/waybar/scripts"

STYLE_BEGIN="/* BEGIN omarchy-supplement (managed block, edited by install-waybar-config.sh) */"
STYLE_END="/* END omarchy-supplement */"

# Check if waybar config exists
if [ ! -d "$WAYBAR_DIR" ]; then
    echo "Waybar config not found at $WAYBAR_DIR"
    echo "Please install waybar first"
    exit 1
fi

# Check if the override config exists
if [ ! -f "$OVERRIDE_CONFIG" ]; then
    echo "Override config not found at $OVERRIDE_CONFIG"
    exit 1
fi

# Waybar has no include mechanism for a whole config the way hyprland has
# source, so the override is a symlink: edits in this repo take effect directly,
# and style.css is left alone.
if [ -e "$WAYBAR_CONFIG" ] && [ ! -L "$WAYBAR_CONFIG" ]; then
    if [ -e "$WAYBAR_CONFIG.bak" ]; then
        echo "Keeping existing backup at $WAYBAR_CONFIG.bak"
    else
        echo "Backing up $WAYBAR_CONFIG to $WAYBAR_CONFIG.bak"
        mv "$WAYBAR_CONFIG" "$WAYBAR_CONFIG.bak"
    fi
fi

echo "Linking config.jsonc to $WAYBAR_CONFIG"
ln -sfn "$OVERRIDE_CONFIG" "$WAYBAR_CONFIG"

# The config's exec lines point at ~/.config/waybar/scripts, so those have to be
# in place too or the custom modules stay empty. Linked file by file rather than
# linking the directory, to leave any unrelated scripts there untouched.
shopt -s nullglob
SCRIPTS=("$OVERRIDE_SCRIPTS"/*.sh)
shopt -u nullglob

if [ ${#SCRIPTS[@]} -gt 0 ]; then
    mkdir -p "$WAYBAR_DIR/scripts"
    for script in "${SCRIPTS[@]}"; do
        chmod +x "$script"
        echo "Linking $(basename "$script") to $WAYBAR_DIR/scripts"
        ln -sfn "$script" "$WAYBAR_DIR/scripts/$(basename "$script")"
    done
fi

# style.css cannot be a symlink like the config: it has to keep omarchy's own
# rules and the theme @import that defines @background. So the override is
# merged in as a marked block instead, which means editing waybar/style.css
# needs another run of this script to take effect.
if [ -f "$OVERRIDE_STYLE" ]; then
    if [ ! -f "$WAYBAR_STYLE" ]; then
        echo "Waybar style not found at $WAYBAR_STYLE"
        exit 1
    fi

    MERGED="$(mktemp)"

    # Drop any previously merged block so re-runs replace it instead of stacking
    # up copies, and trim trailing blank lines to keep the result stable
    awk -v b="$STYLE_BEGIN" -v e="$STYLE_END" '
        $0 == b { skip = 1; next }
        $0 == e { skip = 0; next }
        skip { next }
        { lines[++n] = $0; if (NF) last = n }
        END { for (i = 1; i <= last; i++) print lines[i] }
    ' "$WAYBAR_STYLE" > "$MERGED"

    # Appended last so these rules win the cascade, and so @background from the
    # theme @import at the top of style.css is already defined. awk 1 rather than
    # cat, to guarantee the block ends with a newline.
    {
        printf '\n%s\n' "$STYLE_BEGIN"
        awk 1 "$OVERRIDE_STYLE"
        printf '%s\n' "$STYLE_END"
    } >> "$MERGED"

    if cmp -s "$MERGED" "$WAYBAR_STYLE"; then
        echo "style.css already up to date"
        rm -f "$MERGED"
    else
        if [ ! -e "$WAYBAR_STYLE.bak" ]; then
            echo "Backing up $WAYBAR_STYLE to $WAYBAR_STYLE.bak"
            cp "$WAYBAR_STYLE" "$WAYBAR_STYLE.bak"
        fi
        echo "Merging style.css into $WAYBAR_STYLE"
        cat "$MERGED" > "$WAYBAR_STYLE"
        rm -f "$MERGED"
    fi
fi

# Pick up the new config
if command -v omarchy-restart-waybar >/dev/null; then
    echo "Restarting waybar"
    omarchy-restart-waybar
elif pgrep -x waybar >/dev/null; then
    echo "Reloading waybar"
    pkill -SIGUSR2 -x waybar
fi

echo "Waybar config setup complete!"
