#!/bin/bash

set -e

# The client loads /etc/Nextcloud/sync-exclude.lst as well as this one, so this
# file only has to carry what is added here -- it does not need a copy of the
# shipped defaults to be complete.
EXCLUDE_FILE="$HOME/.config/Nextcloud/sync-exclude.lst"

# $HOME itself is the sync root here (account 0 syncs /home/koen -> /omarchy),
# so every tool that keeps scratch state under it hands the client files that
# are created and deleted again inside a single sync run. Those come back as
# "<file> and N other files could not be synced due to errors", re-announced on
# every retry. install-omarchy-notifications.sh mutes the toast; these patterns
# stop the errors happening in the first place.
#
# Excluding a path does not delete what is already on the server, it only stops
# the client updating it.
EXCLUDES=(
    # Agent scratch. Codex's .codex/tmp/<run>/.lock is the one that shows up in
    # the error toast by name; Claude Code churns the same way under .claude.
    ".claude/"
    ".codex/"
    # Java's user prefs directory holds a lock named .user.lock.<user>, which
    # *.lock below does not match.
    ".java/"
    # Lock files anywhere. Transient by definition, and the sync run is long
    # enough that the file is routinely gone before it is read.
    "*.lock"
    # Atomic-write temporaries, e.g. Bitwarden's data.json.tmp-<hex>.
    "*.tmp-*"
)

echo "Installing the Nextcloud client"
yay -S --noconfirm --needed nextcloud-client

# Created rather than required: on a fresh machine the client has not run yet,
# so there is no user exclude list to append to, and a guard clause that exits
# here would take the whole install-all.sh run with it.
mkdir -p "$(dirname "$EXCLUDE_FILE")"
touch "$EXCLUDE_FILE"

added=0
for pattern in "${EXCLUDES[@]}"; do
    if grep -Fxq "$pattern" "$EXCLUDE_FILE"; then
        continue
    fi
    echo "$pattern" >>"$EXCLUDE_FILE"
    echo "Excluding $pattern from Nextcloud sync"
    added=$((added + 1))
done

if [ "$added" -gt 0 ]; then
    echo "Added $added pattern(s) to $EXCLUDE_FILE"
    echo "Restart the Nextcloud client for them to take effect"
else
    echo "Nextcloud sync exclusions already in place"
fi

echo "Nextcloud setup complete!"
