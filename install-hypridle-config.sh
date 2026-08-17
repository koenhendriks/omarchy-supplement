#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HYPRIDLE_CONFIG="$HOME/.config/hypr/hypridle.conf"
HYPRIDLE_DEFAULT="$HOME/.local/share/omarchy/config/hypr/hypridle.conf"

BLOCK_BEGIN="# BEGIN omarchy-supplement (managed block, edited by install-hypridle-config.sh)"
BLOCK_END="# END omarchy-supplement"

# Idle timings in seconds of real idle time -- what a stopwatch starting the
# moment the keyboard goes quiet would read. The timeouts written into the file
# are derived from these, see the baseline note below.
SCREENSAVER_AFTER=150 # 2.5 min, Omarchy's default
LOCK_AFTER=1800       # 30 min
SUSPEND_AFTER=2400    # 40 min

if [ ! -f "$HYPRIDLE_DEFAULT" ]; then
    echo "Omarchy's default hypridle config not found at $HYPRIDLE_DEFAULT"
    echo "This script layers on top of it, so it cannot run without it"
    exit 1
fi

if [ ! -d "$(dirname "$HYPRIDLE_CONFIG")" ]; then
    echo "Hyprland config directory not found at $(dirname "$HYPRIDLE_CONFIG")"
    echo "Please install hyprland first"
    exit 1
fi

# Launching the screensaver resets hypridle's idle timer, so every listener that
# fires after it counts from the SCREENSAVER_AFTER mark rather than from the start
# of idle. Omarchy's own config works around this with a hardcoded "half + 2s
# margin"; here the offset is subtracted instead, so the three constants above can
# stay wall-clock and stay readable.
LOCK_TIMEOUT=$((LOCK_AFTER - SCREENSAVER_AFTER))
SUSPEND_TIMEOUT=$((SUSPEND_AFTER - SCREENSAVER_AFTER))

if [ "$LOCK_TIMEOUT" -le 0 ] || [ "$SUSPEND_TIMEOUT" -le "$LOCK_TIMEOUT" ]; then
    echo "Idle timings are not in order: screensaver $SCREENSAVER_AFTER, lock $LOCK_AFTER, suspend $SUSPEND_AFTER"
    echo "Each has to be later than the one before it"
    exit 1
fi

# general{} stays Omarchy's: lock_cmd, before_sleep_cmd and inhibit_sleep are what
# make suspend safe (lock first, then wait for it), and they are worth inheriting
# whenever Omarchy changes them. Only the listeners below are ours.
GENERAL="$(awk 'f && /^\}/ { print; exit } /^general[[:space:]]*\{/ { f = 1 } f { print }' "$HYPRIDLE_DEFAULT")"

if [ -z "$GENERAL" ]; then
    echo "No general{} block found in $HYPRIDLE_DEFAULT"
    echo "Its layout must have changed, so check it before trusting the timings here"
    exit 1
fi

# The listeners are written out here rather than kept as a file in hypr/, because
# install-hyprland-overrides.sh globs hypr/*.lua into hyprland.lua -- a
# listener{} block in there is a config error, not an idle timer.
MERGED="$(mktemp)"

{
    printf '%s\n\n' "$GENERAL"
    printf '%s\n' "$BLOCK_BEGIN"
    cat <<EOF
# Every timeout below is offset by the screensaver's own $SCREENSAVER_AFTER s, because
# launching it resets hypridle's idle timer (it warps the cursor between monitors
# with \`hyprctl dispatch focusmonitor\`). Real idle time to each step:
#   screensaver  $SCREENSAVER_AFTER s
#   lock         $LOCK_AFTER s
#   suspend      $SUSPEND_AFTER s
# So the screensaver is up, and the session unlocked, for $LOCK_TIMEOUT s.

listener {
    timeout = $SCREENSAVER_AFTER
    on-timeout = pidof hyprlock || omarchy-launch-screensaver
}

# omarchy-system-lock kills the screensaver, raises hyprlock, and turns the
# display and keyboard backlight off 3 s later.
listener {
    timeout = $LOCK_TIMEOUT
    on-timeout = omarchy-system-lock
    on-resume = omarchy-system-wake
}

# No on-resume needed: general{}'s after_sleep_cmd already restores the displays.
listener {
    timeout = $SUSPEND_TIMEOUT
    on-timeout = systemctl suspend
}
EOF
    printf '%s\n' "$BLOCK_END"
} >"$MERGED"

if cmp -s "$MERGED" "$HYPRIDLE_CONFIG"; then
    echo "hypridle.conf already up to date"
    rm -f "$MERGED"
else
    # A copy rather than a symlink into this repo, deliberately: omarchy-refresh-config
    # installs defaults with `cp -f`, which follows a symlink and would overwrite the
    # file here instead of the one in ~/.config.
    if [ -f "$HYPRIDLE_CONFIG" ] && [ ! -e "$HYPRIDLE_CONFIG.bak" ]; then
        echo "Backing up $HYPRIDLE_CONFIG to $HYPRIDLE_CONFIG.bak"
        cp "$HYPRIDLE_CONFIG" "$HYPRIDLE_CONFIG.bak"
    fi

    echo "Writing idle timings to $HYPRIDLE_CONFIG (screensaver ${SCREENSAVER_AFTER}s, lock ${LOCK_AFTER}s, suspend ${SUSPEND_AFTER}s)"
    cat "$MERGED" >"$HYPRIDLE_CONFIG"
    rm -f "$MERGED"

    # hypridle only reads its config at startup
    if command -v omarchy-restart-hypridle >/dev/null; then
        echo "Restarting hypridle"
        omarchy-restart-hypridle
    elif pgrep -x hypridle >/dev/null; then
        echo "Restarting hypridle"
        pkill -x hypridle
        setsid hypridle >/dev/null 2>&1 &
    fi
fi

echo "Hypridle config setup complete!"
