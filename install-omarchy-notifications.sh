#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/omarchy-plugin.sh"

PACKAGED_PLUGIN="/usr/share/omarchy/shell/plugins/notifications"

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

if ! python3 - "$PLUGIN_DIR/Service.qml" <<'PY'; then
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
source = path.read_text()


def require(text, old, new, label):
    count = text.count(old)
    if count != 1:
        sys.exit("%s: expected exactly 1 match, found %d" % (label, count))
    return text.replace(old, new)


# Toasts are hardcoded to the top-right corner ("Toasts are fixed to the
# top-right corner", Service.qml) with no setting to move them; mako put them at
# top-center and that is where they belong here too. Only the horizontal
# alignment changes -- margins.top still comes from popupPlacement(), so a toast
# keeps clearing a top bar by the same clearance it always did.
source = require(
    source,
    """        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: popupWindow.popupPlacement.margins.top
        anchors.rightMargin: popupWindow.popupPlacement.margins.right""",
    """        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: popupWindow.popupPlacement.margins.top""",
    "toast column anchor",
)

# The column is one card wide, so each card's own alignment decides where it
# sits when widths differ between toasts.
source = require(
    source,
    """            Layout.preferredWidth: card.implicitWidth
            Layout.alignment: Qt.AlignRight""",
    """            Layout.preferredWidth: card.implicitWidth
            Layout.alignment: Qt.AlignHCenter""",
    "card slot alignment",
)

source = require(
    source,
    """            NotificationCard {
              id: card
              anchors.right: parent.right""",
    """            NotificationCard {
              id: card
              anchors.horizontalCenter: parent.horizontalCenter""",
    "card anchor",
)

path.write_text(source)
PY
    echo "Patching $PLUGIN_ID failed; the packaged plugin's shape must have changed"
    restore_previous
    exit 1
fi

plugin_settle

echo "Omarchy notifications setup complete!"
