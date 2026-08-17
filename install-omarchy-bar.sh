#!/bin/bash

set -e

PACKAGED_BAR="/usr/share/omarchy/shell/plugins/bar"
PLUGINS_DIR="$HOME/.config/omarchy/plugins"
PLUGIN_ID="${USER:-$(id -un)}.bar"
PLUGIN_DIR="$PLUGINS_DIR/$PLUGIN_ID"
PREVIOUS_DIR="$PLUGIN_DIR.previous"
SHELL_CONFIG="$HOME/.config/omarchy/shell.json"

if [ ! -f "$PACKAGED_BAR/Bar.qml" ]; then
    echo "Omarchy's packaged bar not found at $PACKAGED_BAR/Bar.qml"
    echo "Omarchy 4 (quattro) or newer is required; run 'omarchy update' first"
    exit 1
fi

# The clone is derived, never hand-edited: it is rebuilt from the packaged bar on
# every run so an `omarchy update` improving the bar is picked up rather than
# frozen at whatever shipped the day it was first cloned.
echo "Rebuilding $PLUGIN_ID from $PACKAGED_BAR"

rm -rf "$PREVIOUS_DIR"
if [ -d "$PLUGIN_DIR" ]; then
    mv "$PLUGIN_DIR" "$PREVIOUS_DIR"
fi

restore_previous() {
    rm -rf "$PLUGIN_DIR"
    if [ -d "$PREVIOUS_DIR" ]; then
        mv "$PREVIOUS_DIR" "$PLUGIN_DIR"
        echo "Restored the previous $PLUGIN_ID"
    fi
}

# `omarchy plugin clone` refuses an existing target, hence the move above. It
# also rewrites the manifest id and records clonedFrom, which keeps the built-in
# widget ids working as IPC targets -- worth not reimplementing here.
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


def optional(text, old, new, label):
    """A patch that may already be upstream: tolerate it being gone."""
    count = text.count(old)
    if count > 1:
        sys.exit("%s: expected at most 1 match, found %d" % (label, count))
    if count == 0:
        print("  %s: already applied upstream, skipping" % label)
    return text.replace(old, new)


# Omarchy's plugin contract says an entry point *accepts* the shell-injected
# properties, and every other one (menu/Menu.qml, notifications/Service.qml)
# declares them plain with defaults. Bar.qml alone marks three of them
# `required`, and QML refuses to instantiate a component whose required
# properties are unset -- so shell.qml's pluginBarLoader, which sets `source`
# and injects afterwards in onLoaded, can never load a cloned bar. Relaxing
# them here costs nothing: the host still injects the real values, and the
# built-in bar path passes them declaratively either way.
source = optional(
    source,
    "  required property string omarchyPath",
    '  property string omarchyPath: Quickshell.env("OMARCHY_PATH")',
    "omarchyPath",
)
source = optional(source, "  required property var barWidgetRegistry", "  property var barWidgetRegistry: null", "barWidgetRegistry")
source = optional(source, "  required property var barConfig", "  property var barConfig: null", "barConfig")

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

if [ -d "$PREVIOUS_DIR" ] && diff -qr "$PREVIOUS_DIR" "$PLUGIN_DIR" >/dev/null 2>&1; then
    echo "$PLUGIN_ID unchanged"
else
    echo "Wrote $PLUGIN_DIR"
fi
rm -rf "$PREVIOUS_DIR"

# Always restart, even when the content came out identical. Rebuilding the clone
# rewrites files inside a directory the shell watches, so it hot-reloads the bar
# plugin no matter what -- and that reload keeps serving the previously compiled
# Bar.qml, which leaves the bar half-initialised: no layer surface, and panels
# holding a null `bar`. Only a full restart recompiles it. (A broken bar shows up
# as *no bar* rather than an error, because shell.qml's fallback path throws
# first, so this is worth being unconditional about.)
echo "Restarting shell to recompile the bar QML"
omarchy restart shell

echo "Omarchy bar setup complete!"
