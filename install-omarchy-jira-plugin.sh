#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/omarchy-plugin.sh"

PLUGIN_URL="https://github.com/koenhendriks/omarchy-menu-jira-plugin.git"
SHELL_CONFIG="$HOME/.config/omarchy/shell.json"
ENV_FILE="$SCRIPT_DIR/.env"

# The Jira this machine works against, and the account the API token belongs to
# (a Jira API token is the password half of HTTP Basic, so it is useless on its
# own).
JIRA_BASE_URL="https://yh-jira.atlassian.net/"
JIRA_EMAIL="koen.hendriks@yourhosting.nl"

# Left empty so the token decides: the plugin filters on the projects the
# account can actually see and caches them, which is a better list than one
# maintained here. Without a token an empty list means every KEY-123 shaped
# query becomes a ticket row, including a search for something like `mp3-320`.
JIRA_PROJECTS='[]'

# Optional, and the only secret here. Absent, the plugin still opens tickets; it
# just cannot look up which projects exist or what a ticket is called.
if [ -f "$ENV_FILE" ]; then
    set -a
    # shellcheck disable=SC1090
    . "$ENV_FILE"
    set +a
fi
JIRA_API_TOKEN="${JIRA_API_TOKEN:-}"

# The work Jira is logged into the yourhosting Chrome profile, so the row cannot
# go through omarchy-launch-browser: that resolves the *default* browser entry,
# which is the personal profile here. Same shape as omarchy-launch-browser's own
# launch (uwsm-app puts the browser in its own systemd scope rather than leaving
# it parented to the shell), with the profile install-chrome-profiles.sh set up.
JIRA_COMMAND='uwsm-app -- google-chrome-stable --profile-directory="Profile 1"'

plugin_init "io.github.koenhendriks.menu-jira"

plugin_add_or_update "$PLUGIN_URL"

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

python3 - "$PLUGIN_ID" "$JIRA_BASE_URL" "$JIRA_EMAIL" "$JIRA_PROJECTS" "$JIRA_COMMAND" \
    "$JIRA_API_TOKEN" "$SHELL_CONFIG" "$MERGED" <<'PY'
import json
import sys

plugin_id, base_url, email, projects_json, command, api_token, config_path, out_path = sys.argv[1:9]

with open(config_path) as handle:
    config = json.load(handle)

entries = config.get("plugins")
if not isinstance(entries, list):
    sys.exit("%s has no plugins list; is the plugin enabled?" % config_path)

for entry in entries:
    if isinstance(entry, dict) and entry.get("id") == plugin_id:
        entry["baseUrl"] = base_url
        entry["email"] = email
        entry["projects"] = json.loads(projects_json)
        entry["command"] = command
        # An empty JIRA_API_TOKEN means "not in .env", which is not the same as
        # "remove the one that is configured": a token pasted into shell.json by
        # hand is still the user's answer and outlives a .env that never had it.
        if api_token:
            entry["apiToken"] = api_token
            # The plugin reads either spelling and prefers this one, so leaving
            # the hyphenated key behind would mean editing it and seeing nothing
            # happen.
            entry.pop("api-token", None)
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

    if [ -n "$JIRA_API_TOKEN" ]; then
        echo "Pointing $PLUGIN_ID at $JIRA_BASE_URL as $JIRA_EMAIL, with an API token"
    else
        echo "Pointing $PLUGIN_ID at $JIRA_BASE_URL (no JIRA_API_TOKEN in .env, so no lookups)"
    fi
    cat "$MERGED" >"$SHELL_CONFIG"
    rm -f "$MERGED"

    # Settings are read off shellConfig, which is reparsed on save, so the new
    # base URL is live on the next keystroke. Only the plugin's QML needs a
    # restart, and this script never touches that.
    echo "Jira base URL applied (shell.json hot-reloads)"
fi

echo "Omarchy menu Jira setup complete!"
