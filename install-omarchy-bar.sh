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
    """A patch that must apply: our own change."""
    count = text.count(old)
    if count != 1:
        sys.exit("%s: expected exactly 1 match, found %d" % (label, count))
    return text.replace(old, new)


def workaround(text, old, new, label):
    """A local workaround, not a patch expected to become redundant on its own.
    Tolerates the pattern being absent so a reshaped Bar.qml does not abort the
    rebuild, but absence is not the expected outcome -- see the note below."""
    count = text.count(old)
    if count > 1:
        sys.exit("%s: expected at most 1 match, found %d" % (label, count))
    if count == 0:
        print("  %s: not declared required, nothing to relax" % label)
    return text.replace(old, new)


# LOCAL WORKAROUND -- delete these three substitutions once
# basecamp/omarchy#7254 has landed on this machine. Check with:
#   grep -A6 "id: pluginBarLoader" /usr/share/omarchy/shell/shell.qml
# If it calls setSource() with a properties map, the fix is in and these can go.
#
# Bar.qml marks three shell-injected properties `required`. QML refuses to
# instantiate a component whose required properties are unset, and shell.qml's
# pluginBarLoader sets `source` and only injects them afterwards in onLoaded --
# so an unrelaxed clone cannot load at all. Relaxing them is what makes the clone
# work here; the host still injects the real values, and the built-in bar path
# passes them declaratively either way.
#
# The accepted upstream fix supplies the properties at creation in shell.qml and
# leaves `required` in Bar.qml. So these substitutions will NOT lapse into no-ops
# when it ships -- they will keep firing, silently and pointlessly, which is why
# they need deleting rather than leaving to expire. The tolerance below is only
# insurance against Bar.qml being reshaped.
source = workaround(
    source,
    "  required property string omarchyPath",
    '  property string omarchyPath: Quickshell.env("OMARCHY_PATH")',
    "omarchyPath",
)
source = workaround(source, "  required property var barWidgetRegistry", "  property var barWidgetRegistry: null", "barWidgetRegistry")
source = workaround(source, "  required property var barConfig", "  property var barConfig: null", "barConfig")

# The actual customisation: cap the bar's width and centre it, so the ultrawide
# gets a 2560px bar instead of one stretched across all 5120px. Driven by
# `bar.maxWidth` in shell.json (see omarchy/shell-bar.json).
source = require(
    source,
    "  readonly property int barSize: vertical ? Style.bar.sizeVertical : Style.bar.sizeHorizontal",
    "  readonly property int barSize: vertical ? Style.bar.sizeVertical : Style.bar.sizeHorizontal\n"
    "\n"
    "  // omarchy-supplement: cap a horizontal bar's width and centre it, so an\n"
    "  // ultrawide does not get a bar stretched across the whole panel.\n"
    "  // 0 = full width, matching stock behaviour.\n"
    "  property int maxWidth: 0",
    "maxWidth property",
)

source = require(
    source,
    '    centerAnchor = Util.canonicalWidgetId(config.centerAnchor || "")',
    '    centerAnchor = Util.canonicalWidgetId(config.centerAnchor || "")\n'
    "    maxWidth = Math.max(0, Number(config.maxWidth) || 0)",
    "maxWidth config read",
)

# Narrow the bar's *content*, not its window. Insetting the window with margins
# looks right but breaks every panel: popups anchor to this window and
# shell/Ui/PopupCard.qml maps the widget's position into its coordinate space,
# so a margin-inset window puts each panel exactly `inset` px left of its icon
# (measured: bluetooth icon at x=3712, panel centre at x=2432, inset 1280).
# PopupCard.qml lives outside this plugin, so it cannot be patched from here --
# hence the window keeps spanning the screen, paints nothing itself, and masks
# input to the painted strip so the uncovered edges stay clickable.
source = require(
    source,
    """    implicitWidth: root.vertical ? root.barSize : 0
    implicitHeight: root.vertical ? 0 : root.barSize
    color: root.transparent ? "transparent" : root.background
    surfaceFormat.opaque: false
    WlrLayershell.namespace: "omarchy-bar"
    WlrLayershell.layer: WlrLayer.Top

    Loader {
      anchors.fill: parent
      sourceComponent: root.vertical ? verticalBar : horizontalBar""",
    """    implicitWidth: root.vertical ? root.barSize : 0
    implicitHeight: root.vertical ? 0 : root.barSize

    // omarchy-supplement: how far in each side of the painted bar sits. The
    // window itself stays full-width so panel anchoring keeps working.
    readonly property int contentInset: root.vertical || root.maxWidth <= 0
      ? 0
      : Math.max(0, Math.round((barWindow.width - root.maxWidth) / 2))

    color: "transparent"
    surfaceFormat.opaque: false
    WlrLayershell.namespace: "omarchy-bar"
    WlrLayershell.layer: WlrLayer.Top

    // Without this the transparent full-width window would swallow clicks along
    // the whole screen edge, not just where the bar is drawn.
    mask: Region { item: barSurface }

    Rectangle {
      id: barSurface

      x: barWindow.contentInset
      y: 0
      width: barWindow.width - barWindow.contentInset * 2
      height: barWindow.height
      color: root.transparent ? "transparent" : root.background
    }

    Loader {
      x: barSurface.x
      y: barSurface.y
      width: barSurface.width
      height: barSurface.height
      sourceComponent: root.vertical ? verticalBar : horizontalBar""",
    "content inset",
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
