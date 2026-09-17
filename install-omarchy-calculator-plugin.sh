#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/omarchy-plugin.sh"

PLUGIN_URL="https://github.com/koenhendriks/omarchy-menu-calculator-plugin.git"

plugin_init "io.github.koenhendriks.menu-calculator"

plugin_add_or_update "$PLUGIN_URL"

# Being present is not enough: the plugin declares `clonedFrom: omarchy.menu`, and
# only an *enabled* clone is what resolveEnabledId() hands the menu to. Installed
# but disabled looks fine in `plugin list` while SUPER still opens the stock menu.
if omarchy plugin list --json |
    python3 -c 'import json,sys; sys.exit(0 if any(p["id"] == sys.argv[1] and p["enabled"] for p in json.load(sys.stdin)) else 1)' "$PLUGIN_ID"; then
    echo "$PLUGIN_ID is enabled"
else
    echo "Enabling $PLUGIN_ID"
    omarchy plugin enable "$PLUGIN_ID"
fi

echo "Omarchy menu calculator setup complete!"
