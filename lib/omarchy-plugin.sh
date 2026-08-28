#!/bin/bash

# Shared by the install-omarchy-*.sh plugin installers. Most of it serves the
# ones that rebuild a derived clone of a first-party Omarchy shell plugin; the
# git-sourced plugins use only plugin_init() for the paths and restart_shell()
# after patching what they cloned.
#
# Sourced, never executed: it defines variables and functions in the caller's
# shell, and install-all.sh already sources those callers. Nothing here runs on
# its own, so it deliberately has no side effects at source time.
#
# Every clone is *derived, never hand-edited*: rebuilt from the packaged plugin on
# every run so an `omarchy update` improving that plugin is picked up rather than
# frozen at whatever shipped the day it was first cloned. Each installer supplies
# the packaged path, the plugin id, and its own patch; everything else is here.

OMARCHY_PLUGINS_DIR="$HOME/.config/omarchy/plugins"

# Staged OUTSIDE ~/.config/omarchy/plugins: the shell scans that directory, so a
# copy parked there is picked up as a live plugin. It does not merely log
# "Local plugin changed, reloading: <id>.previous" -- the shell instantiates the
# staged QML, so the running UI can briefly come from the copy being held for
# rollback.
OMARCHY_STAGING_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/omarchy-supplement"

OMARCHY_SHELL_MATCH="quickshell -n -p /usr/share/omarchy/shell"

# Sets PLUGIN_ID, PLUGIN_DIR and PREVIOUS_DIR for the rest of the installer.
plugin_init() {
    PLUGIN_ID="$1"
    PLUGIN_DIR="$OMARCHY_PLUGINS_DIR/$PLUGIN_ID"
    PREVIOUS_DIR="$OMARCHY_STAGING_DIR/$PLUGIN_ID.previous"
}

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

# Restart the shell without letting it decide the installer's exit status.
# `omarchy restart shell` only polls 2s for readiness and returns non-zero when
# the shell is slower than that, which it intermittently is here. The installers
# are *sourced* by install-all.sh, so that non-zero under `set -e` would abort the
# whole run, the same way the old hypridle script used to.
#
# A new pid is the only proof the QML was recompiled: a shell that was never
# killed keeps serving the previously compiled files and answers `ping` perfectly
# well while doing it. The initial sleep lets the kill and relaunch actually
# happen, so a slow restart is not misread as a skipped one.
restart_shell() {
    local before after waited=0
    before=" $(pgrep -f "$OMARCHY_SHELL_MATCH" | tr '\n' ' ')"

    echo "Restarting shell to load the rebuilt plugin"
    omarchy restart shell >/dev/null 2>&1 || true
    sleep 2

    while [ "$waited" -lt 60 ]; do
        after="$(pgrep -n -f "$OMARCHY_SHELL_MATCH" || true)"
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

# Move any existing clone aside. `omarchy plugin clone` refuses an existing
# target, and keeping the old copy gives a failed patch something to roll back to.
plugin_stage_previous() {
    mkdir -p "$OMARCHY_STAGING_DIR"
    rm -rf "$PREVIOUS_DIR"
    if [ -d "$PLUGIN_DIR" ]; then
        mv "$PLUGIN_DIR" "$PREVIOUS_DIR"
    fi
}

# Put the staged copy back, for when a clone or patch fails mid-rebuild. Leaving
# a half-built plugin in place is worse than leaving the previous one.
restore_previous() {
    rm -rf "$PLUGIN_DIR"
    if [ -d "$PREVIOUS_DIR" ]; then
        mv "$PREVIOUS_DIR" "$PLUGIN_DIR"
        echo "Restored the previous $PLUGIN_ID"
    fi
}

# Report whether the rebuild actually changed anything, drop the rollback copy,
# and restart. The restart is unconditional even when the content came out
# identical: rebuilding rewrites files inside a directory the shell watches, so it
# hot-reloads the plugin either way, and that reload keeps serving the previously
# compiled QML. For the bar that leaves it half-initialised -- no layer surface,
# panels holding a null `bar` -- which shows up as *no bar* rather than an error,
# because shell.qml's fallback path throws first.
plugin_settle() {
    if [ -d "$PREVIOUS_DIR" ] && diff -qr "$PREVIOUS_DIR" "$PLUGIN_DIR" >/dev/null 2>&1; then
        echo "$PLUGIN_ID unchanged"
    else
        echo "Wrote $PLUGIN_DIR"
    fi
    rm -rf "$PREVIOUS_DIR"

    restart_shell
}

# The two guards every installer repeats before cloning.
plugin_require_packaged() {
    if [ ! -f "$1" ]; then
        echo "Omarchy's packaged plugin not found at $1"
        echo "Omarchy 4 (quattro) or newer is required; run 'omarchy update' first"
        return 1
    fi
}

plugin_require_shell() {
    if ! wait_for_shell; then
        echo "The Omarchy shell is not answering; start it and re-run this script"
        return 1
    fi
}

# Copy a file into place only when it differs, echoing either way. Plain copies
# rather than symlinks into this repo: omarchy-refresh-config installs defaults
# with `cp -f`, which follows a symlink and would overwrite the file here instead
# of the one in ~/.config.
install_if_changed() {
    local src="$1" target="$2" mode="${3:-755}"

    if cmp -s "$src" "$target"; then
        echo "$(basename "$target") already up to date in $(dirname "$target")"
    else
        echo "Installing $(basename "$target") to $(dirname "$target")"
        install -m "$mode" "$src" "$target"
    fi
}
