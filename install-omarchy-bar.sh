#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/omarchy-plugin.sh"

PACKAGED_BAR="/usr/share/omarchy/shell/plugins/bar"
SHELL_CONFIG="$HOME/.config/omarchy/shell.json"

plugin_init "${USER:-$(id -un)}.bar"
plugin_require_packaged "$PACKAGED_BAR/Bar.qml" || exit 1

echo "Rebuilding $PLUGIN_ID from $PACKAGED_BAR"
plugin_stage_previous
plugin_require_shell || exit 1

# `omarchy plugin clone` rewrites the manifest id and records clonedFrom, which
# keeps the built-in widget ids working as IPC targets -- worth not
# reimplementing here.
if ! omarchy plugin clone omarchy.bar >/dev/null; then
    echo "Cloning omarchy.bar failed"
    restore_previous
    exit 1
fi

if ! python3 - "$PLUGIN_DIR/Bar.qml" <<'PY'; then
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
source = path.read_text()


def require(text, old, new, label):
    count = text.count(old)
    if count != 1:
        sys.exit("%s: expected exactly 1 match, found %d" % (label, count))
    return text.replace(old, new)


# The customisation: cap a horizontal bar's width and centre it, so the
# ultrawide gets a 2560px bar instead of one stretched across all 5120px.
# Driven by `bar.maxWidth` in shell.json (see omarchy/shell-bar.json); 0 is
# full width, matching stock.
source = require(
    source,
    '  property string position: "top"\n',
    '  property string position: "top"\n'
    "  // omarchy-supplement: widest a horizontal bar may draw, 0 for full width.\n"
    "  property int maxWidth: 0\n",
    "maxWidth property",
)

source = require(
    source,
    "    position = normalizePosition(config.position)\n",
    "    position = normalizePosition(config.position)\n"
    "    maxWidth = Math.max(0, Number(config.maxWidth) || 0)\n",
    "maxWidth config read",
)

# Only the strip narrows. The layer surface already spans the whole screen and
# masks input to barStrip, and popups anchor to that full-width window, so
# narrowing the window instead would put every panel off its icon by the inset.
# The exclusive zone is the strip's thickness along the edge, unaffected by its
# width, so tiled windows still clear the bar across the full screen.
source = require(
    source,
    """      x: root.position === "right" ? parent.width - barWindow.thickness : 0
      y: root.position === "bottom" ? parent.height - barWindow.thickness : 0
      width: root.vertical ? barWindow.thickness : parent.width""",
    """      readonly property real cappedWidth: root.maxWidth > 0
        ? Math.min(parent.width, root.maxWidth) : parent.width
      x: root.position === "right" ? parent.width - barWindow.thickness
        : (root.vertical ? 0 : Math.round((parent.width - cappedWidth) / 2))
      y: root.position === "bottom" ? parent.height - barWindow.thickness : 0
      width: root.vertical ? barWindow.thickness : cappedWidth""",
    "strip width cap",
)

path.write_text(source)
PY
    echo "Patching $PLUGIN_ID failed; the packaged bar's shape must have changed"
    restore_previous
    exit 1
fi

# `omarchy plugin clone` already pointed bar.id at the clone. Say so explicitly
# so a re-run after `omarchy bar use omarchy.bar` puts it back.
python3 - "$SHELL_CONFIG" "$PLUGIN_ID" <<'PY'
import json
import pathlib
import sys

path, plugin_id = pathlib.Path(sys.argv[1]), sys.argv[2]
config = json.loads(path.read_text())
config.setdefault("bar", {})["id"] = plugin_id
path.write_text(json.dumps(config, indent=2, ensure_ascii=False, sort_keys=True) + "\n")
PY

plugin_settle

echo "Omarchy bar setup complete!"
