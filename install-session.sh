#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/omarchy-plugin.sh"

SESSION_SRC="$SCRIPT_DIR/session"
LOCAL_BIN="$HOME/.local/bin"
SESSION_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/hypr-session"
APPS_CONF="$SESSION_CONFIG_DIR/apps.conf"
HOOKS_DIR="$HOME/.config/omarchy/hooks"
POST_BOOT_DIR="$HOOKS_DIR/post-boot.d"
SYSTEMD_USER_DIR="$HOME/.config/systemd/user"
GUARD_UNIT="hypr-session-guard.service"
EXTENSIONS_DIR="$HOME/.config/omarchy/extensions"
MENU_USER="$EXTENSIONS_DIR/omarchy-menu.jsonc"
MENU_DEFAULT="/usr/share/omarchy/default/omarchy/omarchy-menu.jsonc"

for f in hypr-session apps.conf restore-session.hook "$GUARD_UNIT"; do
    if [ ! -f "$SESSION_SRC/$f" ]; then
        echo "Session file not found at $SESSION_SRC/$f"
        exit 1
    fi
done

if [ ! -f "$MENU_DEFAULT" ]; then
    echo "Omarchy's packaged menu not found at $MENU_DEFAULT"
    echo "Omarchy 4 (quattro) or newer is required; run 'omarchy update' first"
    exit 1
fi

if [ ! -d "$HOOKS_DIR" ]; then
    echo "Omarchy hooks directory not found at $HOOKS_DIR"
    echo "Omarchy 4 (quattro) or newer creates it; run 'omarchy update' first"
    exit 1
fi

if [ ! -d "$EXTENSIONS_DIR" ]; then
    echo "Omarchy extensions directory not found at $EXTENSIONS_DIR"
    echo "Omarchy 4 (quattro) or newer creates it; run 'omarchy update' first"
    exit 1
fi

mkdir -p "$LOCAL_BIN" "$SESSION_CONFIG_DIR" "$POST_BOOT_DIR" "$SYSTEMD_USER_DIR"

install_if_changed "$SESSION_SRC/hypr-session" "$LOCAL_BIN/hypr-session"

# Installed into post-boot.d directly rather than with `omarchy hook install`,
# which copies to the flat ~/.config/omarchy/hooks/post-boot path and would
# clobber a hook already living there.
install_if_changed "$SESSION_SRC/restore-session.hook" \
    "$POST_BOOT_DIR/restore-session.hook"

# Seeded once, never refreshed: this is a file the user edits to add apps, so
# re-running install-all.sh must not reset it. Same reasoning as backing up to
# *.bak only when no backup exists.
if [ -f "$APPS_CONF" ]; then
    echo "Session allow-list already present at $APPS_CONF, leaving it alone"
else
    echo "Seeding session allow-list at $APPS_CONF"
    install -m 644 "$SESSION_SRC/apps.conf" "$APPS_CONF"
fi

install_if_changed "$SESSION_SRC/$GUARD_UNIT" "$SYSTEMD_USER_DIR/$GUARD_UNIT" 644

echo "Reloading the user systemd manager"
systemctl --user daemon-reload

if systemctl --user is-enabled "$GUARD_UNIT" >/dev/null 2>&1; then
    echo "$GUARD_UNIT already enabled"
else
    echo "Enabling $GUARD_UNIT"
    systemctl --user enable "$GUARD_UNIT" >/dev/null
fi

# Starting it only inside a graphical session, so installing over ssh does not
# fail on the unit's ConditionEnvironment.
if systemctl --user is-active graphical-session.target >/dev/null 2>&1; then
    if systemctl --user is-active "$GUARD_UNIT" >/dev/null 2>&1; then
        echo "$GUARD_UNIT already active"
    else
        echo "Starting $GUARD_UNIT"
        systemctl --user start "$GUARD_UNIT" || \
            echo "Could not start $GUARD_UNIT; it will start at the next login"
    fi
else
    echo "No graphical session, $GUARD_UNIT will start at the next login"
fi

# The ordering edge is the whole reason the guard unit can save anything, and it
# is one hardcoded unit name away from silently vanishing.
if systemctl --user show "$GUARD_UNIT" -p After --value 2>/dev/null |
        grep -q "wayland-wm@hyprland.desktop.service"; then
    echo "Guard unit is ordered after the compositor, so its ExecStop runs first"
else
    echo "WARNING: $GUARD_UNIT is not ordered after wayland-wm@hyprland.desktop.service"
    echo "Its shutdown save will race the compositor and will usually capture nothing"
fi

# Omarchy's shutdown, reboot and logout rows, rewritten to save the session first.
# This is the only interception point that sees a live session:
# omarchy-system-shutdown arms poweroff on a 2s timer and then runs
# omarchy-hyprland-window-close-all, so by the time any teardown hook fires there
# are no windows left to record.
if [ ! -f "$MENU_USER" ]; then
    echo "Creating $MENU_USER"
    printf '{\n}\n' >"$MENU_USER"
fi

if [ "$(grep -c . "$MENU_USER" | tr -d ' ')" -gt 0 ] &&
        [ "$(grep . "$MENU_USER" | tail -1 | tr -d '[:space:]')" != "}" ]; then
    echo "Refusing to edit $MENU_USER: it does not end with a closing brace"
    echo "Last non-blank line is: $(grep . "$MENU_USER" | tail -1)"
    echo "Fix or delete that file, then re-run this script"
    exit 1
fi

MENU_CANDIDATE="$(mktemp)"

python3 - "$MENU_DEFAULT" "$MENU_USER" "$MENU_CANDIDATE" <<'PY'
import json, re, sys

default_path, user_path, out_path = sys.argv[1:4]

BEGIN = "  // >>> omarchy-supplement session-save (generated, do not edit)"
END = "  // <<< omarchy-supplement session-save"

# Mirror MenuModel.js stripJsonc() exactly: whole-line // comments only, and
# trailing commas tolerated. /* */ is NOT handled there, and a parse failure makes
# parseMenuJsonc() return [] with printErrors:false -- so one bad character
# silently drops the user's ENTIRE menu extension with nothing in the journal.
# That is why the candidate is validated below before it is allowed anywhere near
# the real file.
def strip_jsonc(raw):
    raw = re.sub(r"^\s*//[^\n]*(\n|$)", "", raw, flags=re.M)
    return re.sub(r",(\s*[}\]])", r"\1", raw)

with open(default_path) as fh:
    packaged = json.loads(strip_jsonc(fh.read()))

# icon and label are re-declared rather than inherited, because
# MenuModel.js normalizeItem() emits every key (empty string when absent) and
# mergeMenuSources() copies all of them over the default -- so overriding only
# `action` leaves a row labelled "system.shutdown" with no icon. They are read
# from the packaged file rather than hardcoded so an upstream icon or label change
# still carries over, and so is the base action.
MANAGED = [
    ("system.logout", "menu-logout"),
    ("system.reboot", "menu-reboot"),
    ("system.shutdown", "menu-shutdown"),
]

rows = []

# `;` and not `&&`: a save that fails or is slow must never be able to stop a
# shutdown the user asked for.
for key, trigger in MANAGED:
    base = packaged.get(key)
    if not isinstance(base, dict) or not base.get("action"):
        print("skipping %s: not in the packaged menu" % key, file=sys.stderr)
        continue
    rows.append((key, {
        "icon": base.get("icon", ""),
        "label": base.get("label", key),
        "action": "hypr-session save --trigger=%s; %s" % (trigger, base["action"]),
    }))

rows.append(("system.session-save", {
    "icon": "\U000F0193",
    "label": "Save session",
    "description": "Write the open windows to disk now",
    "aliases": ["save-session"],
    "action": "hypr-session save --trigger=menu-manual",
}))

# ensure_ascii so the glyphs land as \u escapes. Independently needed: the repo
# already records that agent file-editing tools mangle multi-byte codepoints in
# some positions, and an ASCII-only block keeps the cmp -s on re-run stable.
block = [BEGIN]
for key, value in rows:
    block.append('  %s: %s,' % (json.dumps(key), json.dumps(value, ensure_ascii=True)))
block.append(END)

with open(user_path) as fh:
    lines = fh.read().splitlines()

kept, skipping = [], False
for line in lines:
    if line.strip() == BEGIN.strip():
        skipping = True
        continue
    if line.strip() == END.strip():
        skipping = False
        continue
    if not skipping:
        kept.append(line)

close_at = max(i for i, l in enumerate(kept) if l.strip().startswith("}"))
merged = kept[:close_at] + block + kept[close_at:]
candidate = "\n".join(merged) + "\n"

try:
    parsed = json.loads(strip_jsonc(candidate))
except ValueError as e:
    raise SystemExit("generated menu would not parse (%s); refusing to install it" % e)

for key, _ in rows:
    if key not in parsed:
        raise SystemExit("generated menu is missing %s; refusing to install it" % key)

with open(out_path, "w") as fh:
    fh.write(candidate)
PY

if cmp -s "$MENU_CANDIDATE" "$MENU_USER"; then
    echo "Menu session rows already up to date in $MENU_USER"
    rm -f "$MENU_CANDIDATE"
else
    if [ -f "$MENU_USER" ] && [ ! -e "$MENU_USER.bak" ]; then
        echo "Backing up $MENU_USER to $MENU_USER.bak"
        cp "$MENU_USER" "$MENU_USER.bak"
    fi

    echo "Writing menu session rows to $MENU_USER"
    # In place rather than mv: the menu's FileView watches this path, and a
    # rename swaps the inode out from under that watch.
    cat "$MENU_CANDIDATE" >"$MENU_USER"
    rm -f "$MENU_CANDIDATE"
    echo "Menu rows applied (the menu re-reads this file on save)"
fi

echo "Session save and restore setup complete!"
