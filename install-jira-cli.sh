#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ENV_FILE="$SCRIPT_DIR/.env"
NETRC="$HOME/.netrc"
JIRA_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/.jira/.config.yml"

# The same Jira and account as install-omarchy-jira-plugin.sh. Without a trailing
# slash: this string is written to the config verbatim, and it is also what
# jira-cli parses to get the host it looks up in .netrc.
JIRA_BASE_URL="https://yh-jira.atlassian.net"
JIRA_EMAIL="koen.hendriks@yourhosting.nl"

# `jira init` insists on a default project, and which one that should be is a
# preference rather than something to derive. Filled in, the config is generated
# on the next run; left empty, this script still installs and wires up the
# credentials and then prints the one command left to run. `none` is a real
# answer for the board, meaning "no default board", not a board called none.
JIRA_PROJECT=""
JIRA_BOARD="none"

echo "Installing jira-cli"
# The -bin package: the same upstream release, without a Go toolchain to rebuild
# it. Both AUR packages provide `jira` and conflict with each other.
yay -S --noconfirm --needed jira-cli-bin

if [ -f "$ENV_FILE" ]; then
    set -a
    # shellcheck disable=SC1090
    . "$ENV_FILE"
    set +a
fi
JIRA_API_TOKEN="${JIRA_API_TOKEN:-}"

# jira-cli takes the token from $JIRA_API_TOKEN, the config's `api_token`, .netrc
# or the keyring, in that order. .netrc is the one that needs nothing exported per
# shell and survives a later `jira init`, which rewrites the config from scratch.
# The lookup is an exact match on *both* the host and the login, so the `login`
# in the generated config has to be the address used here.
if [ -n "$JIRA_API_TOKEN" ]; then
    NETRC_STATUS=0
    python3 - "$NETRC" "$JIRA_BASE_URL" "$JIRA_EMAIL" "$JIRA_API_TOKEN" <<'PY' || NETRC_STATUS=$?
import os
import sys
from urllib.parse import urlsplit

netrc_path, base_url, login, token = sys.argv[1:5]

host = urlsplit(base_url).hostname
entry = "machine %s login %s password %s\n" % (host, login, token)


def write(text):
    os.umask(0o077)
    with open(netrc_path, "w") as handle:
        handle.write(text)
    os.chmod(netrc_path, 0o600)


if not os.path.exists(netrc_path):
    write(entry)
    sys.exit(0)

with open(netrc_path) as handle:
    lines = handle.readlines()

# A netrc entry may legally span several lines, and rebuilding the file from a
# token stream would drop the comments and grouping someone put there by hand. So
# only the one-line form is edited in place; anything else is reported and left
# alone.
ours = None
for index, line in enumerate(lines):
    fields = line.split()
    if fields[:2] == ["machine", host]:
        if "login" in fields and "password" in fields:
            ours = index
            break
        sys.exit(3)

if ours is None:
    if lines and not lines[-1].endswith("\n"):
        lines[-1] += "\n"
    lines.append(entry)
elif lines[ours] == entry:
    sys.exit(10)
else:
    lines[ours] = entry

write("".join(lines))
PY

    case "$NETRC_STATUS" in
    0)
        echo "Wrote the $JIRA_BASE_URL credentials to $NETRC"
        ;;
    10)
        echo "$NETRC already has the $JIRA_BASE_URL credentials"
        ;;
    3)
        echo "$NETRC already has a multi-line entry for $JIRA_BASE_URL, leaving it alone"
        echo "Point its login at $JIRA_EMAIL and its password at JIRA_API_TOKEN yourself"
        ;;
    *)
        echo "Could not update $NETRC"
        exit 1
        ;;
    esac
else
    echo "No JIRA_API_TOKEN in $ENV_FILE, so jira-cli has no credentials"
    echo "Add it and re-run: every jira command needs it, a read included"
fi

# `jira init` reads the whole project, board, issue type and custom field layout
# off the API, so it needs credentials and cannot be pre-rendered from here. It
# only prompts for what it was not given -- installation, server, login, project
# and board cover all of it -- and --force keeps the "config already exists"
# confirmation from stalling a sourced install-all.sh run.
if [ -f "$JIRA_CONFIG" ]; then
    echo "jira-cli is already configured at $JIRA_CONFIG"
elif [ -z "$JIRA_API_TOKEN" ] || [ -z "$JIRA_PROJECT" ]; then
    echo "Not generating $JIRA_CONFIG: set JIRA_PROJECT in this script, or run"
    echo "  jira init --installation cloud --server $JIRA_BASE_URL --login $JIRA_EMAIL"
else
    echo "Generating $JIRA_CONFIG for project $JIRA_PROJECT"
    if ! jira init --installation cloud --server "$JIRA_BASE_URL" --login "$JIRA_EMAIL" \
        --project "$JIRA_PROJECT" --board "$JIRA_BOARD" --force; then
        echo "jira init failed, so jira-cli is installed but unconfigured"
        echo "Check the token in $ENV_FILE and that $JIRA_PROJECT is a project it can see"
    fi
fi

echo "jira-cli setup complete!"
