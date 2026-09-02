#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/omarchy-plugin.sh"

PLUGIN_URL="https://github.com/koenhendriks/omarchy-menu-jira-plugin.git"
SHELL_CONFIG="$HOME/.config/omarchy/shell.json"

# The Jira this machine works against. `projects` is what keeps the row honest:
# with nothing listed, every KEY-123 shaped query becomes a ticket, so a search
# for something like `mp3-320` would offer to open it in Jira.
JIRA_BASE_URL="https://yh-jira.atlassian.net/"
JIRA_PROJECTS='["SWD"]'

plugin_init "io.github.koenhendriks.menu-jira"

# Same reason as install-omarchy-calculator-plugin.sh: `omarchy plugin add`
# exits non-zero on an id that is already installed, and this script is *sourced*
# by install-all.sh, so an unguarded second run would take the whole run with it.
# Pulling new upstream commits is `omarchy plugin update`'s job, not this one's.
if [ -d "$PLUGIN_DIR" ]; then
    echo "$PLUGIN_ID is already installed"
else
    echo "Adding $PLUGIN_ID"
    omarchy plugin add "$PLUGIN_URL" --enable --yes
fi

# Enabling a service plugin is what mounts it inside omarchy-shell, and it is
# also what puts the entry in shell.json that the settings below are written to.
# Unlike the menu calculator this plugin clones nothing, so a disabled one is
# simply absent rather than quietly leaving the stock behaviour in place.
if omarchy plugin list --json |
    python3 -c 'import json,sys; sys.exit(0 if any(p["id"] == sys.argv[1] and p["enabled"] for p in json.load(sys.stdin)) else 1)' "$PLUGIN_ID"; then
    echo "$PLUGIN_ID is enabled"
else
    echo "Enabling $PLUGIN_ID"
    omarchy plugin enable "$PLUGIN_ID"
fi

if [ ! -f "$SHELL_CONFIG" ]; then
    echo "Omarchy shell config not found at $SHELL_CONFIG"
    echo "Enabling the plugin should have created it; run 'omarchy restart shell' and re-run this script"
    exit 1
fi

# The plugin's own entry in shell.json is where its base URL lives, and
# `omarchy plugin enable` writes that entry as a bare {"id": ...}. Merged rather
# than rewritten, for the same reason install-omarchy-shell.sh merges the bar
# key: this file also holds the bar layout, idle timings and every other plugin
# registration.
MERGED="$(mktemp)"

python3 - "$PLUGIN_ID" "$JIRA_BASE_URL" "$JIRA_PROJECTS" "$SHELL_CONFIG" "$MERGED" <<'PY'
import json
import sys

plugin_id, base_url, projects_json, config_path, out_path = sys.argv[1:6]

with open(config_path) as handle:
    config = json.load(handle)

entries = config.get("plugins")
if not isinstance(entries, list):
    sys.exit("%s has no plugins list; is the plugin enabled?" % config_path)

for entry in entries:
    if isinstance(entry, dict) and entry.get("id") == plugin_id:
        entry["baseUrl"] = base_url
        entry["projects"] = json.loads(projects_json)
        break
else:
    sys.exit("%s is not in %s's plugins list" % (plugin_id, config_path))

with open(out_path, "w") as handle:
    json.dump(config, handle, indent=2, ensure_ascii=False, sort_keys=True)
    handle.write("\n")
PY

if cmp -s "$MERGED" "$SHELL_CONFIG"; then
    echo "$PLUGIN_ID already points at $JIRA_BASE_URL"
    rm -f "$MERGED"
else
    if [ ! -e "$SHELL_CONFIG.bak" ]; then
        echo "Backing up $SHELL_CONFIG to $SHELL_CONFIG.bak"
        cp "$SHELL_CONFIG" "$SHELL_CONFIG.bak"
    fi

    echo "Pointing $PLUGIN_ID at $JIRA_BASE_URL"
    cat "$MERGED" >"$SHELL_CONFIG"
    rm -f "$MERGED"

    # Settings are read off shellConfig, which is reparsed on save, so the new
    # base URL is live on the next keystroke. Only the plugin's QML needs a
    # restart, and this script never touches that.
    echo "Jira base URL applied (shell.json hot-reloads)"
fi

echo "Omarchy menu Jira setup complete!"
