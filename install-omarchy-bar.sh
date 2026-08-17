#!/bin/bash

set -e

PACKAGED_BAR="/usr/share/omarchy/shell/plugins/bar"
PLUGINS_DIR="$HOME/.config/omarchy/plugins"
PLUGIN_ID="${USER:-$(id -un)}.bar"
PLUGIN_DIR="$PLUGINS_DIR/$PLUGIN_ID"
# Staged OUTSIDE ~/.config/omarchy/plugins: the shell scans that directory, so a
# copy parked there is picked up as a live plugin. It does not merely log
# "Local plugin changed, reloading: <id>.previous" -- the shell instantiates the
# staged Bar.qml/Service.qml, so the running UI can briefly come from the copy
# being held for rollback.
STAGING_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/omarchy-supplement"
PREVIOUS_DIR="$STAGING_DIR/$PLUGIN_ID.previous"
SHELL_CONFIG="$HOME/.config/omarchy/shell.json"
SHELL_MATCH="quickshell -n -p /usr/share/omarchy/shell"

# `omarchy plugin clone` enables the clone over the shell's IPC socket, so it
# needs a shell that is answering. Straight after a restart that can take a few
# seconds longer than omarchy-restart-shell is willing to wait, and the clone
# fails with "omarchy-shell is not running" if it goes first.
wait_for_shell() {
    local waited=0
    while [ "$waited" -lt 40 ]; do
        if omarchy-shell shell ping >/dev/null 2>&1; then
            return 0
        fi
        sleep 0.5
        waited=$((waited + 1))
    done
    return 1
}

# Restart the shell without letting it decide this script's exit status.
# `omarchy restart shell` only polls 2s for readiness and returns non-zero when
# the shell is slower than that, which it intermittently is here. This file is
# *sourced* by install-all.sh, so that non-zero under `set -e` would abort the
# whole run, the same way the old hypridle script used to.
#
# A new pid is the only proof the QML was recompiled: a shell that was never
# killed keeps serving the previously compiled files and answers `ping` perfectly
# well while doing it. The initial sleep lets the kill and relaunch actually
# happen, so a slow restart is not misread as a skipped one.
restart_shell() {
    local before after waited=0
    before=" $(pgrep -f "$SHELL_MATCH" | tr '\n' ' ')"

    echo "Restarting shell to load the rebuilt plugin"
    omarchy restart shell >/dev/null 2>&1 || true
    sleep 2

    while [ "$waited" -lt 60 ]; do
        after="$(pgrep -n -f "$SHELL_MATCH" || true)"
        if [ -n "$after" ] && [ "${before/ $after / }" = "$before" ] &&
            omarchy-shell shell ping >/dev/null 2>&1; then
            echo "Shell restarted (pid $after)"
            return 0
        fi
        sleep 0.5
        waited=$((waited + 1))
    done

    echo "Warning: the shell did not restart within 30s, so it may still be"
    echo "serving the previously compiled QML. The plugin is written correctly;"
    echo "run 'omarchy restart shell' by hand to load it."
}

if [ ! -f "$PACKAGED_BAR/Bar.qml" ]; then
    echo "Omarchy's packaged bar not found at $PACKAGED_BAR/Bar.qml"
    echo "Omarchy 4 (quattro) or newer is required; run 'omarchy update' first"
    exit 1
fi

# The clone is derived, never hand-edited: it is rebuilt from the packaged bar on
# every run so an `omarchy update` improving the bar is picked up rather than
# frozen at whatever shipped the day it was first cloned.
echo "Rebuilding $PLUGIN_ID from $PACKAGED_BAR"

mkdir -p "$STAGING_DIR"
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
if ! wait_for_shell; then
    echo "The Omarchy shell is not answering; start it and re-run this script"
    exit 1
fi

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
restart_shell

echo "Omarchy bar setup complete!"
