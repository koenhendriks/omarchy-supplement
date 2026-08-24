#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/omarchy-plugin.sh"

PLUGIN_URL="https://github.com/stappmus/Omarchy-Spotify.git"

# Where the plugin's own scripts/setup.sh puts the playback backend and the user
# unit that runs it. Checked rather than assumed, so setup only runs once.
BACKEND_BINARY="${OMARCHY_SPOTIFY_RUNTIME_DIR:-$HOME/.local/lib/omarchy-spotify}/omarchy-spotify-backend"
PLAYBACK_UNIT="$HOME/.config/systemd/user/omarchy-spotify.service"

plugin_init "quickshell.spotify"

# The plugin's scripts/setup.sh hard-fails on any of these being absent, and it
# names the missing command rather than the package, so install them here. All
# four are no-ops on a system that already has them. gnome-keyring is where the
# saved Spotify session lives; secret-tool (libsecret) is how the plugin talks to
# it, socat carries the backend's control socket, and avahi-browse is what finds
# Spotify Connect receivers on the LAN.
echo "Installing the Spotify plugin's runtime dependencies"
yay -S --noconfirm --needed gnome-keyring libsecret socat avahi

# Same reason as install-omarchy-calculator-plugin.sh: `omarchy plugin add` exits
# non-zero on an id that is already installed, and this script is *sourced* by
# install-all.sh, so an unguarded second run would take the whole run with it.
# Pulling new upstream commits is `omarchy plugin update`'s job, not this one's.
if [ -d "$PLUGIN_DIR" ]; then
    echo "$PLUGIN_ID is already installed"
else
    echo "Adding $PLUGIN_ID"
    omarchy plugin add "$PLUGIN_URL" --enable --yes
fi

# A disabled bar widget is dropped from the shell's widget registry, and the
# layout entry in omarchy/shell-bar.json then matches nothing and renders an
# empty slot without a word in the log. See the bar-layout note in README.md.
if omarchy plugin list --json |
    python3 -c 'import json,sys; sys.exit(0 if any(p["id"] == sys.argv[1] and p["enabled"] for p in json.load(sys.stdin)) else 1)' "$PLUGIN_ID"; then
    echo "$PLUGIN_ID is enabled"
else
    echo "Enabling $PLUGIN_ID"
    omarchy plugin enable "$PLUGIN_ID"
fi

if [ ! -x "$PLUGIN_DIR/scripts/setup.sh" ]; then
    echo "$PLUGIN_ID has no scripts/setup.sh at $PLUGIN_DIR"
    echo "Remove it with 'omarchy plugin remove $PLUGIN_ID' and re-run this script"
    exit 1
fi

# Run the plugin's setup here rather than leaving it to the mini-player's "Set up
# and continue" button, so a fresh machine comes up with local playback already
# working. Only the browser sign-in is left, and that cannot be scripted.
#
# Guarded on the backend and the unit both being present, not just re-run: setup.sh
# also pipes a device name through scripts/configure-spotifyd.sh, which rewrites
# `device_name` in ~/.config/omarchy-spotify/spotifyd.conf. It defaults to
# "Omarchy Spotify", so an unguarded re-run would quietly undo a rename made in
# the widget's own settings.
if [ -x "$BACKEND_BINARY" ] && [ -f "$PLAYBACK_UNIT" ]; then
    echo "Playback backend already installed at $BACKEND_BINARY"
else
    echo "Installing the playback backend and its user unit"
    status=0
    "$PLUGIN_DIR/scripts/setup.sh" || status=$?

    case "$status" in
    0)
        echo "Playback backend installed; sign in from the bar widget to finish"
        ;;
    30)
        # setup.sh's own exit code for "no bundled binary for this architecture,
        # no cargo to build one, and no spotifyd either". Not fatal: Spotify
        # Connect control of another device still works, only playback on this
        # machine does not, so the run carries on.
        echo "Warning: no playback backend could be installed for $(uname -m)"
        echo "Install rust (for the plugin's own backend) or spotifyd (as a"
        echo "fallback), then re-run this script. The plugin still works as a"
        echo "remote control for other Spotify Connect devices."
        ;;
    *)
        echo "The plugin's scripts/setup.sh failed with status $status"
        exit 1
        ;;
    esac
fi

echo "Omarchy Spotify setup complete!"
