#!/bin/bash

set -e

SYSTEM_DESKTOP="/usr/share/applications/google-chrome.desktop"
LOCAL_DIR="$HOME/.local/share/applications"

# name:profile-directory. The directory is the literal name under
# ~/.config/google-chrome, which Chrome appends to the user data dir as-is --
# "Default" is capitalised on disk and a lowercase "default" would silently
# create a new empty profile instead of opening this one.
PROFILES=(
    "koen:Default"
    "yourhosting:Profile 1"
)

if [ ! -f "$SYSTEM_DESKTOP" ]; then
    echo "Desktop entry not found at $SYSTEM_DESKTOP"
    echo "Is google-chrome installed?"
    exit 1
fi

mkdir -p "$LOCAL_DIR"

for entry in "${PROFILES[@]}"; do
    name="${entry%%:*}"
    profile="${entry#*:}"
    target="$LOCAL_DIR/google-chrome-$name.desktop"

    # Only the Name in [Desktop Entry] is renamed: the [Desktop Action] sections
    # have their own Name (New Window, New Incognito Window) that must stay.
    # Every Exec gets the profile appended, including the actions, so opening a
    # new or incognito window from this launcher stays in the same profile.
    # The command is taken from whatever the packaged entry says rather than
    # hardcoded, so an upstream change to the binary or its flags carries over.
    awk -v name="$name" -v profile="$profile" '
        /^\[/ { section = $0 }
        section == "[Desktop Entry]" && /^Name=/ { print "Name=Google Chrome " name; next }
        /^Exec=/ { print $0 " --profile-directory=\"" profile "\""; next }
        { print }
    ' "$SYSTEM_DESKTOP" > "$target"
    chmod 644 "$target"

    echo "Wrote $target"
    grep -E "^(Name|Exec)=" "$target" | sed 's/^/    /'
done

if command -v update-desktop-database >/dev/null; then
    update-desktop-database "$LOCAL_DIR"
fi

echo "Chrome profile launchers setup complete!"
