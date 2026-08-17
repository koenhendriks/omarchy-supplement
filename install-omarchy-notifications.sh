#!/bin/bash

set -e

PACKAGED_PLUGIN="/usr/share/omarchy/shell/plugins/notifications"
PLUGINS_DIR="$HOME/.config/omarchy/plugins"
PLUGIN_ID="${USER:-$(id -un)}.notifications"
PLUGIN_DIR="$PLUGINS_DIR/$PLUGIN_ID"
# Staged OUTSIDE ~/.config/omarchy/plugins: the shell scans that directory, so a
# copy parked there is picked up as a live plugin. It does not merely log
# "Local plugin changed, reloading: <id>.previous" -- the shell instantiates the
# staged Bar.qml/Service.qml, so the running UI can briefly come from the copy
# being held for rollback.
STAGING_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/omarchy-supplement"
PREVIOUS_DIR="$STAGING_DIR/$PLUGIN_ID.previous"
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

if [ ! -f "$PACKAGED_PLUGIN/Service.qml" ]; then
    echo "Omarchy's packaged notifications plugin not found at $PACKAGED_PLUGIN/Service.qml"
    echo "Omarchy 4 (quattro) or newer is required; run 'omarchy update' first"
    exit 1
fi

# Same derived-clone approach as install-omarchy-bar.sh: rebuilt from the
# packaged plugin every run so an omarchy update is picked up rather than frozen.
echo "Rebuilding $PLUGIN_ID from $PACKAGED_PLUGIN"

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

# Cloning a plugin with a non-widget kind makes the registry add the source to
# `disabledPlugins` in shell.json, so only one notification service ever runs --
# no duplicate toasts and no fight over the org.freedesktop.Notifications name.
# It also records `cloneSourceRestores`, so disabling the clone brings the
# built-in service back.
if ! wait_for_shell; then
    echo "The Omarchy shell is not answering; start it and re-run this script"
    exit 1
fi

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

if [ -d "$PREVIOUS_DIR" ] && diff -qr "$PREVIOUS_DIR" "$PLUGIN_DIR" >/dev/null 2>&1; then
    echo "$PLUGIN_ID unchanged"
else
    echo "Wrote $PLUGIN_DIR"
fi
rm -rf "$PREVIOUS_DIR"

# Unconditional, for the reason spelled out in install-omarchy-bar.sh: rebuilding
# files the shell watches always triggers a plugin hot reload, and that reload
# keeps serving the previously compiled QML.
restart_shell

echo "Omarchy notifications setup complete!"
