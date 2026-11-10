#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/omarchy-plugin.sh"

PACKAGED_PLUGIN="/usr/share/omarchy/shell/plugins/notifications"

# Apps that never get to put a toast on screen. Matched case-insensitively
# against the freedesktop `app_name`, which is the string history files under
# ~/.local/state/omarchy/notifications/history record as `app`.
#
# Nextcloud is here because its desktop client re-announces every sync failure
# and has no setting that stops it: every notification toggle in nextcloud.cfg
# is already off and the "Sync Activity" error toasts still arrive, while the
# same message is already sitting in the client's own activity list.
MUTED_APPS=("Nextcloud")

plugin_init "${USER:-$(id -un)}.notifications"
plugin_require_packaged "$PACKAGED_PLUGIN/Service.qml" || exit 1

echo "Rebuilding $PLUGIN_ID from $PACKAGED_PLUGIN"
plugin_stage_previous
plugin_require_shell || exit 1

# Cloning a plugin with a non-widget kind makes the registry add the source to
# `disabledPlugins` in shell.json, so only one notification service ever runs --
# no duplicate toasts and no fight over the org.freedesktop.Notifications name.
# It also records `cloneSourceRestores`, so disabling the clone brings the
# built-in service back.
if ! omarchy plugin clone omarchy.notifications >/dev/null; then
    echo "Cloning omarchy.notifications failed"
    restore_previous
    exit 1
fi

if ! python3 - "$PLUGIN_DIR/Service.qml" "${MUTED_APPS[@]}" <<'PY'; then
import json
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
source = path.read_text(encoding="utf-8")
muted = json.dumps(sorted(set(app.lower() for app in sys.argv[2:])))


def require(text, old, new, label):
    count = text.count(old)
    if count != 1:
        sys.exit("%s: expected exactly 1 match, found %d" % (label, count))
    return text.replace(old, new)


# The deck hangs from the top-right corner with no setting to move it; mako put
# toasts at top-center and that is where they belong here too. The layer surface
# drops its right anchor, which makes the compositor centre it, and the clipper
# inside it centres too. The clipper's width used to carry margins.right as the
# gap from the screen edge; with no edge to clear it gets the motion inset on
# both sides instead, or the deck sits a few pixels left of centre.
# margins.top still comes from marginsFor(), so a toast keeps clearing a top bar.
source = require(
    source,
    """      anchors { top: true; bottom: true; right: true }""",
    """      anchors { top: true; bottom: true }""",
    "surface anchors",
)

source = require(
    source,
    """        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: surface.margins.top
        // Room for the arrival's scale animation, and the gap from the edge.
        readonly property int motionInset: Style.spacing.sm
        width: service.notificationWidth + motionInset + surface.margins.right""",
    """        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: surface.margins.top
        // Room for the arrival's scale animation on either side.
        readonly property int motionInset: Style.spacing.sm
        width: service.notificationWidth + 2 * motionInset""",
    "deck clipper",
)

# There is no per-app mute in the shell -- the quiet state is a single `dnd`
# boolean and nothing else -- so the filter has to go in the service, at the
# one point every notification passes through.
source = require(
    source,
    """  function handleNotification(notification) {""",
    """  // Apps whose toasts are dropped on arrival. Lower-cased by the installer
  // that writes this list, so the lookup below stays a plain comparison.
  readonly property var mutedApps: %s

  function isMuted(row) {
    return mutedApps.indexOf(String(row.app || "").toLowerCase()) !== -1
  }

  function handleNotification(notification) {""" % muted,
    "muted app list",
)

# Muted apps reuse the quiet branch rather than getting one of their own: the
# wanted behaviour is identical (no toast, but a history entry, so it can still
# be scrolled back through), and isEphemeral() already decides which of those are worth recording at all. Checked before
# quietReason(), whose DND bypasses (Omarchy's own toasts, verification codes)
# exist to cut through DND, and nothing should let a muted app cut through a mute.
source = require(
    source,
    """    var muted = Delivery.quietReason(row, doNotDisturb)""",
    """    var muted = service.isMuted(row) ? "muted" : Delivery.quietReason(row, doNotDisturb)""",
    "muted app filter",
)

path.write_text(source, encoding="utf-8")
PY
    echo "Patching $PLUGIN_ID failed; the packaged plugin's shape must have changed"
    restore_previous
    exit 1
fi

plugin_settle

echo "Omarchy notifications setup complete!"
