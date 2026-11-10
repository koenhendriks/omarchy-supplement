#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/omarchy-plugin.sh"

PACKAGED_WIDGET="/usr/share/omarchy/shell/plugins/bar/widgets/Workspaces.qml"
TOGGLE="omarchy-supplement-workspace-layout-toggle"
LOCAL_BIN="$HOME/.local/bin"

plugin_init "${USER:-$(id -un)}.workspaces"
plugin_require_packaged "$PACKAGED_WIDGET" || exit 1

# The clone calls the toggle by name, so it has to be on PATH before the shell
# restarts onto the clone.
mkdir -p "$LOCAL_BIN"
install_if_changed "$SCRIPT_DIR/omarchy/bin/$TOGGLE" "$LOCAL_BIN/$TOGGLE"

echo "Rebuilding $PLUGIN_ID from $PACKAGED_WIDGET"
plugin_stage_previous
plugin_require_shell || exit 1

# Like the clock, cloning rewrites the bar layout entry from omarchy.workspaces to
# <user>.workspaces, which omarchy/shell-bar.json spells "@user@.workspaces".
if ! omarchy plugin clone omarchy.workspaces >/dev/null; then
    echo "Cloning omarchy.workspaces failed"
    restore_previous
    exit 1
fi

if ! python3 - "$PLUGIN_DIR/Workspaces.qml" "$TOGGLE" <<'PATCH'; then
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
toggle = sys.argv[2]
source = path.read_text()


def require(text, old, new, label):
    count = text.count(old)
    if count != 1:
        sys.exit("%s: expected exactly 1 match, found %d" % (label, count))
    return text.replace(old, new)


# Clicking the active workspace cycles its layout through the stock toggle,
# which knows nothing of custom_center. The supplement toggle adds it to the
# cycle on the ultrawide's workspaces and hands every other workspace back to
# the stock one.
source = require(
    source,
    '    var command = "omarchy-hyprland-workspace-layout-toggle"',
    '    var command = "%s"' % toggle,
    "toggle command",
)

# Without its own glyph custom_center shows the tiling square, and the two
# cannot be told apart from the bar.
source = require(
    source,
    '    if (mode === "floating") return "󰔶"',
    '    if (mode === "floating") return "󰔶"\n'
    '    if (mode === "lua:custom_center") return "\\uf0db"',
    "custom_center glyph",
)

path.write_text(source)
PATCH
    echo "Patching $PLUGIN_ID failed; the packaged widget's shape must have changed"
    restore_previous
    exit 1
fi

plugin_settle

echo "Omarchy workspaces setup complete!"
