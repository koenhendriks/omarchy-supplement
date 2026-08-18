#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/omarchy-plugin.sh"

PLUGIN_URL="https://github.com/Shavanced/omarchy-notification-center-plugin.git"

plugin_init "shavanced.notification-center"

# `omarchy plugin add` refuses an id that is already installed and exits
# non-zero ("update it with: omarchy plugin update"). This script is *sourced*
# by install-all.sh, so an unguarded second run would take the whole run with
# it. Adding only when the directory is absent is what makes it re-runnable;
# picking up new upstream commits is `omarchy plugin update`'s job, not this
# script's, because an update would silently drop the patch below.
if [ -d "$PLUGIN_DIR" ]; then
    echo "$PLUGIN_ID is already installed"
else
    echo "Adding $PLUGIN_ID"
    omarchy plugin add "$PLUGIN_URL" --enable --yes
fi

if [ ! -f "$PLUGIN_DIR/BarWidget.qml" ]; then
    echo "$PLUGIN_ID has no BarWidget.qml at $PLUGIN_DIR"
    echo "Remove it with 'omarchy plugin remove $PLUGIN_ID' and re-run this script"
    exit 1
fi

# Unlike the derived clones, this plugin is not rebuilt from source on every
# run, so the patch has to be idempotent itself: exit 10 when it is already
# applied, and only then is skipping the restart safe.
status=0
python3 - "$PLUGIN_DIR/BarWidget.qml" <<'PY' || status=$?
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
source = path.read_text(encoding="utf-8")


def patch(text, marker, old, new, label):
    if marker in text:
        sys.exit(10)
    count = text.count(old)
    if count != 1:
        sys.exit("%s: expected exactly 1 match, found %d" % (label, count))
    return text.replace(old, new)


source = patch(
    source,
    "readonly property string notificationServiceId",
    """  readonly property var notificationService: hostShell && hostShell.firstPartyServiceFor
    ? hostShell.firstPartyServiceFor("omarchy.notifications") : null""",
    """  // Resolved through the registry rather than asked for by name, so that a
  // *clone* of the notifications service is found too. shell.qml's serviceFor()
  // is an exact-id lookup, and cloning a plugin with a non-widget kind disables
  // its source, so firstPartyServiceFor("omarchy.notifications") returns null
  // for as long as <user>.notifications is the live implementation -- and this
  // widget then shows no live notifications, no history and no DND, with
  // nothing in the log to say why. resolveEnabledId() maps a built-in id onto
  // whichever enabled plugin declares `clonedFrom` it and hands the id straight
  // back when none does, so this is correct with or without the clone.
  readonly property var hostPluginRegistry: hostShell && hostShell.pluginRegistry
    ? hostShell.pluginRegistry : null
  readonly property string notificationServiceId: hostPluginRegistry && hostPluginRegistry.resolveEnabledId
    ? String(hostPluginRegistry.resolveEnabledId("omarchy.notifications")) : "omarchy.notifications"
  readonly property var notificationService: hostShell && hostShell.serviceFor
    ? hostShell.serviceFor(notificationServiceId) : null""",
    "notification service lookup",
)

path.write_text(source, encoding="utf-8")
PY

case "$status" in
0)
    echo "Pointed $PLUGIN_ID at the enabled notifications service"
    restart_shell
    ;;
10)
    echo "$PLUGIN_ID already points at the enabled notifications service"
    ;;
*)
    echo "Patching $PLUGIN_ID failed; its shape must have changed upstream"
    exit 1
    ;;
esac

echo "Omarchy notification centre setup complete!"
