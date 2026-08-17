#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/omarchy-plugin.sh"

PACKAGED_PLUGIN="/usr/share/omarchy/shell/plugins/panels/clock"

plugin_init "${USER:-$(id -un)}.clock"
plugin_require_packaged "$PACKAGED_PLUGIN/Panel.qml" || exit 1

echo "Rebuilding $PLUGIN_ID from $PACKAGED_PLUGIN"
plugin_stage_previous
plugin_require_shell || exit 1

# Cloning a bar widget rewrites the layout entry's id in place -- omarchy.clock
# becomes <user>.clock -- and keeps the entry's own settings (format, formatAlt
# and so on). The source then reports as "disabled" only because nothing in the
# layout names it any more. omarchy/shell-bar.json spells the id as "@user@.clock"
# so this repo stays user-agnostic; install-omarchy-shell.sh substitutes it.
if ! omarchy plugin clone omarchy.clock >/dev/null; then
    echo "Cloning omarchy.clock failed"
    restore_previous
    exit 1
fi

if ! python3 - "$PLUGIN_DIR/Panel.qml" <<'PATCH'; then
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
source = path.read_text()

# The calendar popup is hardcoded to centre itself on the bar, which is invisible
# while the clock sits in the middle and wrong the moment it does not: the
# centerOnBar branch of Ui/PopupCard.qml ignores the icon and uses
# `window.width / 2`, so a clock on the right opens its calendar in the middle of
# the screen.
#
# Made configurable rather than flipped to false outright, so stock behaviour
# stays the default and omarchy/shell-bar.json decides per placement. The panel
# already reads birthYear, lifeExpectancy and weekStartDay through setting().
old = "    centerOnBar: true"
new = '    centerOnBar: root.setting("centerOnBar", true)'

count = source.count(old)
if count != 1:
    sys.exit("centerOnBar: expected exactly 1 match, found %d" % count)

path.write_text(source.replace(old, new, 1))
PATCH
    echo "Patching $PLUGIN_ID failed; the packaged plugin's shape must have changed"
    restore_previous
    exit 1
fi

plugin_settle

echo "Omarchy clock setup complete!"
