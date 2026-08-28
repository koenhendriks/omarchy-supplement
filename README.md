# omarchy-supplement

Personal additions on top of [Omarchy](https://omarchy.org): extra packages, a
few Hyprland and Quickshell overrides, and two work VPNs moved off NetworkManager.

Everything is driven by small `install-*.sh` scripts. They are idempotent 
and they write to `~/.config` and `/etc` rather than expecting you to
symlink this repo yourself.

## Quick start

    git clone <this repo> ~/omarchy-supplement
    cd ~/omarchy-supplement
    cp .env.example .env      # fill in the VPN credentials
    ./install-all.sh

`install-all.sh` sources each script in dependency order. Several steps use
`sudo` and will prompt.

A fresh clone cannot finish the VPN step on its own: `vpn/certs/` is gitignored
and has to be restored out of band first. See [Secrets](#secrets).

## Layout

Scripts are listed in the order `install-all.sh` runs them: strip the stock
install down first, then add packages, then layer config on top.

| Path | What it is |
| --- | --- |
| `install-all.sh` | Runs everything below, in order |
| `install-browser.sh` | Installs Chrome and makes it the default browser |
| `remove-default-browsers.sh` | Drops the browsers Omarchy ships (firefox, brave, edge, zen) |
| `remove-webapps.sh` | Clears every Omarchy webapp |
| `remove-preinstalled.sh` | Drops preinstalled apps not wanted here (obsidian, libreoffice, signal, …) |
| `install-bind.sh` | `bind`, for `dig` and friends |
| `install-nano.sh` | nano, which Omarchy does not ship |
| `install-bitwarden.sh` | Bitwarden desktop and CLI |
| `install-1password.sh` | 1Password desktop and CLI |
| `install-phpstorm.sh` | PhpStorm and its bundled JRE |
| `install-sublime-text.sh` | Sublime Text 4 |
| `install-nextcloud.sh` | Nextcloud client, plus sync exclusions for agent scratch and lock files |
| `install-glab.sh` | GitLab CLI |
| `install-teams.sh` | Teams for Linux |
| `install-outlook.sh` | Outlook as an Omarchy webapp |
| `install-yaak.sh` | Yaak, with a WebKitGTK workaround in its desktop entry |
| `install-wifiman.sh` | WifiMan Desktop, with the same WebKitGTK workaround |
| `install-opendeck.sh` | OpenDeck (Stream Deck), plus a udev reload the pacman hook misses |
| `install-chrome-profiles.sh` | Per-profile Chrome launchers (`koen`, `yourhosting`) |
| `install-le-ca.sh` | Let's Encrypt roots into the system trust store |
| `install-openvpn.sh` | openvpn3, plus a fix to its profile storage |
| `install-strongswan.sh` | strongSwan, plus non-root `swanctl` access |
| `install-vpn.sh` | Imports both VPN profiles, rendering secrets from `.env` |
| `install-satty.sh` | satty, for the `ALT + SHIFT + 4` screenshot binding |
| `install-hyprland-overrides.sh` | Adds `dofile()` lines for `hypr/*.lua` |
| `install-omarchy-bar.sh` | Rebuilds the `<user>.bar` plugin: a patched clone with `maxWidth` |
| `install-omarchy-notifications.sh` | Rebuilds the `<user>.notifications` plugin: top-centre toasts and a muted-app list |
| `install-omarchy-clock.sh` | Rebuilds the `<user>.clock` plugin: makes `centerOnBar` configurable |
| `install-omarchy-calculator-plugin.sh` | Adds the menu calculator plugin, which stands in for the built-in `omarchy.menu` |
| `install-omarchy-spotify-plugin.sh` | Adds the Omarchy Spotify plugin and installs its playback backend up front |
| `install-omarchy-shell.sh` | Merges `omarchy/shell-bar.json` into the Quickshell bar layout, installs the bar's command scripts, and puts the VPN toggle on `PATH` as `vpn` |
| `install-omarchy-notification-plugin.sh` | Adds the third-party notification centre, patched to find the cloned service |
| `install-session.sh` | Installs `hypr-session`, its post-boot hook and shutdown-save guard, and rewrites the menu's shutdown rows |
| `lib/omarchy-plugin.sh` | Shared clone/patch/restart helpers for the plugin installers |
| `hypr/` | Hyprland override modules in Lua (bindings, monitors, windows, input) |
| `omarchy/` | Quickshell bar layout fragment, plus the scripts its command modules run |
| `session/` | The `hypr-session` tool, its allow-list, its post-boot hook and its systemd guard unit |
| `vpn/` | VPN profiles and certificates -> see [vpn/README.md](vpn/README.md) |

## Config overrides

**Hyprland** keeps its own config; the installer only appends a `dofile()` line
per file in `hypr/` to `~/.config/hypr/hyprland.lua`, so those modules stay
authoritative and Omarchy's defaults are never edited. They load last, after
Omarchy's defaults and after `~/.config/hypr/*.lua`, so they win.

`hypr/monitors.lua` is the one override that differs per machine: it branches on
whether an `eDP-1` connector is present, giving the XPS 15's internal panel plain
dwindle on workspaces 1-10, and the desktop its ultrawide + Dell arrangement with
`custom_center` on workspaces 1-5. The branch is not cosmetic -- a workspace rule
applies wherever the workspace lands, so without it the ultrawide's layout also
lands on the laptop's panel. See the note below.

Omarchy 4 (quattro) moved Hyprland from `.conf` to Lua. The overrides here use
Omarchy's own helpers — `o.bind` for keys, `o.window` for window rules — rather
than raw `hl.*` calls, so they keep the descriptions that
`omarchy menu keybindings --print` renders and pick up whatever `o.bind` learns
to do next. Input is the exception: `follow_mouse`, the plain Caps Lock and the
three- and four-finger workspace swipes in `hypr/input.lua` have no `o.*`
wrapper, so they go through `hl.config` and `hl.gesture` directly.

**The bar** is Quickshell now, not waybar: Omarchy 4 (quattro) replaced waybar
with `omarchy-shell`, and most of what used to be a custom waybar module is a
first-party widget. `omarchy/shell-bar.json` holds the wanted bar layout, and
`install-omarchy-shell.sh` merges it into the `bar` key of
`~/.config/omarchy/shell.json`, leaving `idle`, `plugins`, and `version` alone.

The mapping from the old waybar config:

| waybar | Quickshell |
| --- | --- |
| `custom/omarchy`, `hyprland/workspaces` | `omarchy.menu`, `omarchy.workspaces` |
| `mpris` | `omarchy.media` |
| `hyprland/window` | `omarchy.active-window` |
| `custom/weather`, `custom/update` | `omarchy.weather`, `omarchy.system-update` |
| `custom/voxtype`, `custom/screenrecording-indicator`, `custom/idle-indicator`, `custom/notification-silencing-indicator` | `omarchy.indicators` (Dictation, ScreenRecording, StayAwake, Dnd) |
| `custom/claudebar` | `omarchy.agents` |
| `tray`, `bluetooth`, `network`, `pulseaudio` | `omarchy.tray`, `omarchy.bluetooth`, `omarchy.network`, `omarchy.audio` |
| `battery`, `clock` | `omarchy.power`, `omarchy.clock` |
| `cpu` (a btop launcher) | `cpu`, a custom command module reading out CPU temperature and load |
| `custom/vpn-mass`, `custom/vpn-sand` | `vpn-mass`, `vpn-sand`, custom command modules running `omarchy/bar/vpn` |

The VPN script is `omarchy/bar/vpn`, which
`install-omarchy-shell.sh` copies to `~/.config/omarchy/bar/scripts/` where
`shell.json` points at it. A **single click toggles** the tunnel — `vpn toggle
<name>` connects when it is down and disconnects when it is up — rather than
waybar's left-to-connect / right-to-disconnect split.

The same installer drops a second copy at `~/.local/bin/vpn`, so anything other
than the bar can drive the tunnels — a Stream Deck key, a Hyprland binding, a
script:

    vpn toggle MassMarket
    vpn status Sandwave

Two copies rather than a symlink into `~/.config`, so a caller on `PATH` keeps
working when the bar's script directory is rebuilt or reset; both are written from
`omarchy/bar/vpn` on every installer run, so they cannot drift.

`status` and `toggle` are subcommands of one script deliberately: both have to
decide whether a VPN is up, and two copies of that check would eventually
disagree, giving a toggle that connects while the bar reads connected. A
standalone `~/.local/bin/vpn-toggle` used to hold the toggle half; its logic was
absorbed here and that script removed, so the bar has no dependency outside a
fresh clone of this repo — the `vpn` on `PATH` is the same file, not a second
implementation.

Its `class` is an array — `["connected", "active"]` — because `active` is the only
class the bar reacts to (`Bar.qml`: `klass.indexOf("active")`) and it is what
draws the widget lit, while the descriptive class stays readable for anything
else. The glyphs are `\u` escapes rather than literal characters, since agent
editing tools strip multi-byte codepoints in some positions.

`omarchy/bar/cpu` is installed the same way and replaces what used to be a bare
btop-launcher icon: it prints CPU temperature in celsius and load as a
percentage. The sensor is located by hwmon *name* (`k10temp` on AMD, `coretemp`
on Intel) rather than by path, because hwmon numbering is not stable across
boots, and the package label (`Tctl` / `Tdie` / `Package id 0`) is preferred over
the per-core inputs beside it. Load is a delta between runs, cached in
`XDG_RUNTIME_DIR`: `/proc/stat` counts jiffies since boot, so one read says
nothing about now, and caching means the figure covers the poll interval without
the script having to sleep.

**Clock on the right.** `panels/clock/Panel.qml` hardcodes `centerOnBar: true`,
and `Ui/PopupCard.qml` honours that by ignoring the icon entirely and using
`window.width / 2` — so a clock anywhere but the middle opens its calendar in the
centre of the screen. `install-omarchy-clock.sh` clones the widget and turns that
literal into `root.setting("centerOnBar", true)`, so stock behaviour stays the
default and `omarchy/shell-bar.json` decides per placement. `omarchy.weather`
hardcodes it the same way, and will need the same treatment if it ever leaves the
centre.

Cloning a bar widget rewrites the layout entry's id in place — `omarchy.clock`
becomes `<user>.clock` — and keeps the entry's own settings. Because that id is
per-user, the fragment spells it `@user@.clock` and
`install-omarchy-shell.sh` substitutes the placeholder when merging, so the
checked-in layout carries no particular username.

**Bar width on the ultrawide.** waybar had `"width": 2560`, so on the 5120px AOC
the bar covered the middle half. Quickshell has no width setting — the bar
anchors left+right and fills the monitor — so `install-omarchy-bar.sh` clones the
built-in bar into `~/.config/omarchy/plugins/<user>.bar` and adds one: a
`maxWidth` property, set to 2560 via `bar.maxWidth` in `shell.json` (from
`omarchy/shell-bar.json`). That centres the bar on DP-1 and leaves the 2560px
Dell untouched.

What it narrows is the bar's **content**, not its window: the window still spans
the screen, paints nothing itself, and masks pointer input to the painted strip
so the uncovered edges stay clickable. Insetting the window with margins is the
obvious implementation and it breaks every panel — see the note below.

The clone is **derived, never hand-edited**: every run rebuilds it from the
packaged bar and re-applies the patches, so an `omarchy update` that improves the
bar is picked up instead of frozen at the day it was cloned. Re-run
`install-omarchy-bar.sh` after each `omarchy update`. If Omarchy reshapes the
code the patches anchor to, the script refuses to write and restores the previous
clone rather than leaving a broken bar.

Two plugins are cloned this way — bar and clock — and the
mechanics they share live in `lib/omarchy-plugin.sh`: staging the old copy outside
the watched plugins directory, waiting for the shell's IPC before cloning,
rolling back a failed patch, and the pid-checked restart. Each installer is then
just its guards, its `omarchy plugin clone` call, and its own patch. Two bugs in
that block had to be fixed three times before it was shared, which is the reason
it is shared.

**Notifications** come from two pieces that have to be installed together.

`install-omarchy-notifications.sh` rebuilds `<user>.notifications`, a clone of the
first-party service, with two patches. The first moves toasts from the top-right
corner, where `Service.qml` hardcodes them, to the top centre. The second adds a
`mutedApps` list, because the shell has no per-app mute at all — `notifications.json`
holds a single `dnd` boolean and nothing else. A muted app is routed down the
existing DND branch: no toast, but still a history entry, so the notification
centre can be scrolled back through. The list is `MUTED_APPS` at the top of the
installer, matched case-insensitively against the freedesktop `app_name`.

`Nextcloud` is on it. Its desktop client re-announces every sync failure and has
no setting that stops it: every notification toggle in `nextcloud.cfg` is already
off and the `Sync Activity` error toasts still arrive, while the same message is
already sitting in the client's own activity list.

That mute is the symptom half. The cause half is in `install-nextcloud.sh`, which
appends sync exclusions for the files that fail: `$HOME` itself is the sync root
(account 0 syncs `/home/koen` to `/omarchy`), so agent scratch directories and
lock files are created and deleted again inside a single sync run, and the client
reports each one as an error. The patterns are appended line by line, guarded by
`grep -Fxq`, because the file also carries hand-added entries and the client loads
`/etc/Nextcloud/sync-exclude.lst` alongside it — this file is a supplement to the
shipped list, not a replacement for it, and does not need a copy of its contents.
Excluding a path stops the client updating what is already on the server; it does
not delete it. The client has to be restarted to pick the patterns up.

The notification centre itself is a third-party bar widget,
[Shavanced/omarchy-notification-center-plugin](https://github.com/Shavanced/omarchy-notification-center-plugin),
installed by `install-omarchy-notification-plugin.sh` and placed in the bar as
`shavanced.notification-center`. It ships asking for the first-party service by
name, which the clone displaces, so the installer patches that lookup to go
through `resolveEnabledId()` — see below. Without that patch the two cannot
coexist and the widget silently shows nothing.

**The menu** is the built-in one with arithmetic added.
[koenhendriks/omarchy-menu-calculator-plugin](https://github.com/koenhendriks/omarchy-menu-calculator-plugin)
is installed by `install-omarchy-calculator-plugin.sh` and declares
`clonedFrom: omarchy.menu`, so enabling it disables the built-in menu and takes
over every route into it — the `SUPER` keybind, `omarchy menu`, and any script
that summons `omarchy.menu` — without a keybinding changing anywhere. Typing an
expression into the search field puts the answer on top as a real menu row;
`Enter` copies it. Anything that is not arithmetic leaves the results alone.

It is *not* a derived clone: nothing here rebuilds or patches it, so it is
installed once and updated with `omarchy plugin update
io.github.koenhendriks.menu-calculator`. What the installer does beyond adding it
is check that it is *enabled*, because an installed-but-disabled clone leaves the
stock menu in place while `omarchy plugin list` still shows the plugin.

Because it is also a bar widget, the layout fragment names it rather than
`omarchy.menu` for the Omarchy button — see below.

**Idle** is no longer overridden here. Omarchy 4 (quattro) removed hypridle
entirely; idle timings now live in `~/.config/omarchy/shell.json` under `idle`,
and stay at Omarchy's defaults.

## Session save and restore

`hypr-session` records the open windows on shutdown and rebuilds them at the next
login: which app, on which workspace, tiled or floating, and for Chrome the exact
tabs it had open.

    hypr-session save        # snapshot now
    hypr-session show        # what is currently saved
    hypr-session restore     # rebuild it, without waiting for a login
    hypr-session restore --dry-run   # print the hyprctl calls and launch nothing

Only apps listed in `~/.config/hypr-session/apps.conf` are touched. That file is
seeded once from `session/apps.conf` and then left alone, so re-running
`install-all.sh` never resets it. To add an app, open it and run
`hypr-session save -v`: every window it skipped is printed with the matcher line
that would have caught it.

Three things trigger a save, and only the first sees a live session:

| Trigger | When |
| --- | --- |
| The menu's Shutdown / Reboot / Logout rows | Runs the save *before* handing over to `omarchy-system-*` |
| `hypr-session save`, or the menu's "Save session" row | On demand |
| `ExecStop=` on `hypr-session-guard.service` | A shutdown that bypasses the menu, best-effort |

The menu rows are the authoritative path, because Omarchy closes every window
before it powers off (see below), which leaves nothing for a teardown-time hook
to record. The guard unit is a net for `systemctl poweroff` over ssh; it may
legitimately capture nothing, and `hypr-session` refuses to overwrite a good
snapshot with an empty capture so that a useless run cannot destroy a real one.

Restoring happens automatically from `~/.config/omarchy/hooks/post-boot.d/`.
Windows are relaunched one at a time, in the order they were created, because
that arrival order *is* what reproduces the tiling layout -- `hypr/custom-layout.lua`
builds its window order from it and keeps no state across a restart. Placement is
by workspace only and never by monitor name: `hypr/monitors.lua` already pins every
workspace to a monitor, so a session saved on the desktop lands sanely on the
laptop, where floating geometry is re-derived from the monitor's own dimensions.

Read what it did with `journalctl --user -t hypr-session -b`.

A terminal that had a Claude Code session open comes back on that same
conversation, not just in the right directory: the session id is pinned at save
time and the terminal is relaunched as
`foot --working-directory=<cwd> bash -lc 'claude --resume <id>; exec bash -i'`.
Quitting claude leaves a shell behind rather than closing the window.

On the ultrawide's `custom_center` workspaces the layout comes back too, per
workspace: how many windows share the centre half, and which window sits in which
slot -- including one promoted to master with `SUPER + RETURN` despite being the
newest window. Both are recovered by reading back where the layout put things,
because `custom-layout.lua` keeps that state in memory only.

Deliberately not restored: which project PhpStorm had open (only the IDE knows),
the channel or view inside Slack and Teams, and any other program that was
running inside a terminal (the working directory and a claude session are
restored, an arbitrary command is not). For Chrome, all windows of one profile
share one process, so each profile that had windows is relaunched and rebuilds its
own window set, but which profile's window lands on which workspace is
best-effort. Only the first profile launched actually starts Chrome; the rest are
forwarded to that running instance, and a forwarded restore was observed
reopening one window for a profile whose last session had two. So a second
profile with several windows can come back short, and `Ctrl + Shift + T` in it
reopens the rest.

## VPNs

Two connections, two protocols, two clients. Both replaced NetworkManager
profiles, and neither is reachable through `nmcli` any more.

| | MassMarket | Sandwave |
| --- | --- | --- |
| Protocol | OpenVPN | IKEv2/IPsec |
| Client | openvpn3 | strongSwan |
| Up | `openvpn3 session-start --config MassMarket` | `swanctl --initiate --child Sandwave` |
| Down | `openvpn3 session-manage --config MassMarket --disconnect` | `swanctl --terminate --ike Sandwave` |
| Status | `openvpn3 sessions-list` | `swanctl --list-sas` |

Waybar shows both as `MM` and `SW` indicators: left click connects, right click
disconnects. [vpn/README.md](vpn/README.md) covers the conversion details.

## Secrets

`.env` holds the VPN credentials and is gitignored; `.env.example` documents the
required variables. `install-vpn.sh` reads it and renders the credential files
each client needs, nothing secret is committed.

Also gitignored, and required at install time but never committed:
`vpn/certs/` (the OpenVPN client certificate and private key) and the original
`vpn/*.nmconnection` files, which contain passwords in plaintext.

## Things that cost time to work out

Non-obvious behaviour this repo works around. Each has a comment at the relevant
line, collected here so it is findable.

- **openvpn3 stores a *snapshot* of a profile.** Certificates and credential
  files are inlined at import time. Editing `vpn/MassMarket.ovpn` does nothing
  until `install-vpn.sh` re-imports it, and `vpn/certs/` must stay where it is.
- **openvpn3's `--persistent` silently fails out of the box.** Its config
  manager runs as the `openvpn` user, but the package ships
  `/var/lib/openvpn3/configs` as `root:root`, so profiles vanish when the service
  idles out or the machine reboots. `install-openvpn.sh` fixes the ownership.
- **Compression has to be a profile override, not a directive.** The MassMarket
  server pushes compression; openvpn3 rejects it by default and tears the session
  down one line after connecting. `allow-compression` inside the `.ovpn` is
  parsed and then ignored, only `config-manage --allow-compression asym` works.
- **`serviceFor()` is an exact-id lookup, so a cloned service is invisible to
  anything that asks for the original by name.** Cloning a plugin with a
  non-widget kind adds the source to `disabledPlugins`, which is what keeps a
  single notification daemon on the bus — but `shell.qml`'s `serviceFor()` does no
  `clonedFrom` resolution, so `firstPartyServiceFor("omarchy.notifications")`
  returns null for as long as `<user>.notifications` is the live implementation.
  The third-party notification centre then renders an empty popup: no live list,
  no history, no DND, and nothing in the journal to say why, because a null there
  is a perfectly legal binding result. `PluginRegistry.resolveEnabledId()` is the
  resolution `serviceFor()` lacks — it maps a built-in id onto whichever enabled
  plugin declares `clonedFrom` it and returns the id unchanged when none does —
  and `install-omarchy-notification-plugin.sh` patches the widget to go through
  it. Anything else that looks a first-party service up by name has the same hole.
- **A bar layout entry naming a cloned widget renders an empty slot, silently.**
  `serviceFor()`'s hole above has a twin on the bar. `shell.qml`'s
  `syncPluginWidgets()` registers each *enabled* widget under its own
  `manifest.id` and drops the registration of anything disabled, and the bar's
  `ModuleSlot` looks the layout entry's id up in that registry verbatim — no
  `clonedFrom` resolution on this path either. So once the calculator plugin
  disables `omarchy.menu`, an entry still saying `omarchy.menu` matches nothing,
  falls through to the empty module, and the Omarchy button simply is not there:
  no warning, no gap, nothing in the log. `omarchy/shell-bar.json` names
  `io.github.koenhendriks.menu-calculator` for that reason. `omarchy plugin
  enable` does rewrite the live `shell.json` entry in place, which is why the
  button reappears by itself — but it reinserts it *after* `omarchy.workspaces`
  rather than where it was, so `install-omarchy-calculator-plugin.sh` runs before
  `install-omarchy-shell.sh` and the layout merge puts it back at the front.
- **There is no per-app mute anywhere in the shell.** `notifications.json` is
  `{version, dnd}` and that is the whole of it; the only per-app list in
  `NotificationLogic.js` is `isEphemeralApp()`, hardcoded to `notify-send` and
  `omarchy-action`, and it decides recording, not display. Muting one noisy app
  means patching the service, which means cloning it — hence the hole above.
- **`omarchy plugin add --enable` puts a bar widget on the bar itself, and the
  layout merge then takes it away again.** A widget plugin's `manifest.json`
  declares a `defaultSection`, and adding it rewrites the live `shell.json` to
  insert the widget there, so it appears on the bar the moment it is installed —
  which is exactly what makes the loss hard to spot. `install-omarchy-shell.sh`
  merges `omarchy/shell-bar.json` over the `bar` key, and `layout` is one value:
  the fragment's three sections replace the live ones wholesale, dropping every
  entry the fragment does not name. So the widget is on the bar right after
  `install-omarchy-spotify-plugin.sh` and gone again one script later, with
  nothing logged and the plugin still enabled in `plugin list`. Any newly added
  widget needs its id in the fragment; `quickshell.spotify` is there for this
  reason.
- **The Spotify plugin's `scripts/setup.sh` resets the Connect device name.** It
  is the script the mini-player's "Set up and continue" button runs, and it pipes
  a device name — defaulting to `Omarchy Spotify` — through
  `scripts/configure-spotifyd.sh`, which rewrites `device_name` in
  `~/.config/omarchy-spotify/spotifyd.conf`. Re-running it therefore undoes a
  rename made in the widget's own settings, so
  `install-omarchy-spotify-plugin.sh` runs it only when the backend binary or its
  user unit is missing rather than on every pass. It also exits **30**, not 1,
  when no playback backend can be built for the architecture; that one is a
  warning here rather than a failure, because Spotify Connect control of other
  devices still works without a local backend.
- **`omarchy plugin add` exits non-zero on a plugin it already has.** It fails
  with "plugin '<id>' is already installed; update it with: omarchy plugin
  update". The installers here are *sourced*, so an unguarded `omarchy plugin
  add` aborts the entire `install-all.sh` run on its second pass — and it aborts
  at the plugin step, so everything after it is skipped too. Both third-party
  plugin installers check for the directory first.
- **The notification "centre" is a toast replay, not a panel.**
  `omarchy-shell notifications showHistory` re-shows past notifications through
  the normal toast column (`Service.qml`'s `showRecentHistory`), so history appears
  wherever toasts appear — top-right by default — and not anchored to whatever widget
  opened it. Nothing to reposition per-widget; moving history means moving toasts.
- **A Lua-registered layout is selected as `lua:<name>`, not `<name>`.**
  `hl.layout.register("custom_center", ...)` registers fine, and a workspace rule
  or `general:layout` set to the bare `custom_center` is accepted without a word
  of complaint — `hyprctl getoption general:layout` even reports it back. It just
  silently falls through to the default layout: `recalculate` is never called and
  windows keep their dwindle geometry, which reads as "my layout code is broken"
  rather than "the name never resolved". `hyprctl configerrors` stays clean and
  the Hyprland log says nothing. The prefix is the whole fix, so
  `hypr/monitors.lua` pins `lua:custom_center`. Load order does *not* matter — the
  registry is consulted when laying out, so `custom-layout.lua` may be sourced
  after the `monitors.lua` that references it.
- **`o.bind` takes the description second.** `o.bind(keys, description,
  dispatcher)`. Passing a dispatcher as the second argument leaves the real one
  `nil` and Hyprland rejects the bind with `hl.bind: dispatcher must be a
  dispatcher (e.g. hl.dsp.window.close()) or a lua function` — one error per call,
  and the binding simply does not exist afterwards. The description is not
  optional decoration: it is what `omarchy menu keybindings --print` and SUPER + K
  list.
- **`hyprctl keyword` is dead under the Lua parser.** It answers `keyword can't
  work with non-legacy parsers. Use eval.` — `hyprctl eval 'hl.config({...})'`
  replaces it. Note eval applies the value without re-selecting a layout, so a
  layout change needs `hyprctl reload` to take effect.
- **A bar with no background is `bar.transparent`, not a broken patch.** The bar
  paints `Color.bar.background` unless `bar.transparent` is true in `shell.json`,
  and that flag is easy to set by accident: `omarchy bar transparent toggle`, or a
  double-left-click on empty centre-bar space. It looks exactly like the
  width-capping patch having gone wrong, so check the flag first —
  `omarchy bar transparent false` puts it back. `omarchy/shell-bar.json`
  deliberately does not pin it, so the double-click gesture keeps working; the
  cost is that a stray toggle survives until it is flipped back by hand.
- **Narrowing the bar *window* silently misplaces every panel.** Insetting the
  bar's left/right layer-shell margins to centre a narrower bar looks perfect
  until a panel is opened: `shell/Ui/PopupCard.qml` anchors popups to the bar
  window and maps the widget's position into that window's coordinate space, so
  each panel lands exactly `inset` px to the left of its own icon. Measured with
  a 1280px inset: the bluetooth icon's underline at x=3712, its panel centred at
  x=2432. `centerOnBar` widgets (clock, weather) hide the bug, because centring
  on a bar that is itself centred looks right either way — so test with
  bluetooth, network, or agents, never the clock. `PopupCard.qml` sits outside
  the bar plugin and so cannot be patched from the clone, which is why the width
  cap narrows the content and leaves the window alone.
- **A cloned bar cannot load on stock Omarchy 4.0.0.** `omarchy plugin clone
  omarchy.bar` reports success and switches `bar.id`, then the bar disappears
  from every monitor with nothing printed. `Bar.qml` declares `omarchyPath`,
  `barWidgetRegistry`, and `barConfig` as `required property`, and QML will not
  instantiate a component whose required properties are unset — but
  `shell.qml`'s `pluginBarLoader` sets `source:` and only injects them afterwards
  in `onLoaded`, so the component is never built and `configureBar()`'s
  `if (!target) return` makes it a no-op. `Bar.qml` is the only entry point doing
  this; `menu/Menu.qml` and `notifications/Service.qml` declare the same
  properties plain with defaults. `install-omarchy-bar.sh` relaxes them in the
  clone, which is what makes the bar work here. Reported and fixed upstream
  ([#7253](https://github.com/basecamp/omarchy/issues/7253),
  [#7254](https://github.com/basecamp/omarchy/pull/7254)), but the accepted fix
  supplies the properties at creation in `shell.qml` and leaves `required` in
  `Bar.qml`. So it is a **local workaround to delete by hand** once that lands —
  it will not lapse into a no-op, it will keep firing silently and pointlessly.
  Check whether it can go with
  `grep -A6 "id: pluginBarLoader" /usr/share/omarchy/shell/shell.qml`: a
  `setSource()` with a properties map means the fix is in.
- **A broken bar plugin fails silently, and takes the fallback with it.**
  `shell.qml`'s `Loader.Error` handler reads `errorString`, which `Loader` does
  not have. The `ReferenceError` aborts the handler before
  `shell.failedBarId = shell.activeBarId`, so the fallback to the built-in bar
  never runs. That is why the symptom is "no bar" rather than an error message —
  worth knowing before debugging a bar that vanished. Recover with
  `omarchy bar use omarchy.bar && omarchy restart shell`.
- **`omarchy restart shell` reports failure on a perfectly good restart.** It
  kills the shell, relaunches it, then polls readiness for 20 × 0.1s — two
  seconds. The shell needs a shade longer than that here, so it prints "Omarchy
  shell did not become ready after restart." and exits non-zero while the shell
  comes up fine moments later. In a script that `install-all.sh` *sources*, that
  non-zero under `set -e` aborts the whole run, so the plugin installers call it
  with `|| true` and wait for the shell themselves. They check for a **new pid**
  rather than a successful `ping`: a shell that was never killed answers `ping`
  quite happily while still serving the previously compiled QML.
- **A spare copy left in `~/.config/omarchy/plugins/` gets loaded.** The shell
  scans that directory, so staging the old clone as `<id>.previous` beside the
  real one for rollback does not just log
  `Local plugin changed, reloading: <id>.previous` — the shell *instantiates* the
  staged `Bar.qml`, and the running bar can briefly come from the copy being held
  in reserve. Both installers therefore stage into
  `~/.cache/omarchy-supplement/` instead. Anything parked in the plugins dir is
  live, including backups.
- **`omarchy plugin clone` needs a shell that is answering.** It enables the clone
  over the shell's IPC socket, so run straight after a restart it fails with
  "omarchy-shell is not running". Both plugin installers wait for `shell ping`
  before cloning.
- **A QML change needs `omarchy restart shell`, not a hot reload.** Saving a file
  under `~/.config/omarchy/plugins/` logs `Local plugin changed, reloading` and
  the shell keeps serving the previously compiled QML, so an edit looks like it
  did nothing — the stale copy even reports errors against the *new* line
  numbers, which makes it look like the edit did not save. `shell.json` genuinely
  does hot-reload; QML does not.
- **A Quickshell widget is "enabled" by being in the bar layout.** There is no
  separate on/off list: `omarchy plugin enable omarchy.media` just inserts
  `{"id": "omarchy.media"}` into `bar.layout` in `shell.json`, and
  `omarchy plugin list` reports anything absent from the layout as `disabled`.
  So writing the layout is all it takes — but a widget missing from the layout
  will not appear no matter what else is configured, which is why
  `omarchy.media` and `omarchy.active-window` needed adding rather than just
  moving. `omarchy.power` is the exception worth knowing: it is in the layout
  and still draws nothing on a desktop, because it hides itself without a
  battery.
- **A custom bar module needs no `exec`.** The command module renders
  `settings.text` when the command produces no output, and its timer only runs
  when `exec` is non-empty — so a static icon with an `onClick` is a valid module
  with no polling at all. Nothing here uses that shape any more (`cpu` polls now),
  but it is the cheap way to add a launcher button.
- **Command modules with an `exec` add a burst of QML noise on every layout
  rebuild.** Each rebuild logs ~112 `QQmlVMEMetaObject: Internal error -
  attempted to evaluate a function in an invalid context` lines, immediately after
  the `moduleName` TypeError below and from the same broken injection: the poll's
  `onStreamFinished` fires against an instance the rebuild is tearing down.
  Measured A/B — 112 with the two VPN modules present, 0 without. It is a
  one-off per rebuild, not per poll (two 20s steady-state windows: zero), and the
  widgets read correct state throughout. Noise, not breakage.
- **Command modules log a harmless `moduleName` TypeError.** The bar's
  `injectProps()` in `Bar.qml` assigns `bar`, `moduleName`, and `settings` into
  every custom module, but the built-in `CustomCommandModule` declares
  `moduleName` and `settings` as `readonly` and derives both from its own
  `entry`. The assignment throws, which also skips the `settings` line after
  it — and neither matters, because the component already has correct values.
  Expect one `WARN ... Cannot assign to read-only property "moduleName"` per
  module per monitor in `journalctl --user`.
- **`omarchy.media` and `omarchy.active-window` show the same text while
  browser media plays.** Not a duplicated widget: the MPRIS track and the
  focused window title genuinely match when the focused window is the one
  playing. Worth remembering before "fixing" it.
- **`omarchy-refresh-config` writes through a symlink.** It installs defaults with
  `cp -f`, which follows the destination symlink, so pointing a file under
  `~/.config` at a copy in this repo would have an `omarchy refresh` overwrite the
  repo copy rather than the one in `~/.config`. Any config that has an
  `omarchy refresh` for it must be installed as a plain file, not symlinked —
  which is why `install-omarchy-shell.sh` copies `omarchy/bar/vpn` into place
  instead of linking it.
- **`hypr/*.lua` is globbed into `hyprland.lua`.** `install-hyprland-overrides.sh`
  appends a `dofile()` line for every `.lua` in `hypr/`, so config for a *different*
  hypr daemon cannot be parked there — it all reaches Hyprland itself.
- **`dofile()`, not `require()`, for the Hyprland Lua overrides.** Two reasons.
  `package.path` covers `~/.config/?.lua` and `$OMARCHY_PATH`, not this repo, so
  `require` cannot find these files without editing the path first. And
  `default/hypr/bootstrap.lua` only clears `package.loaded` for the `hypr.`,
  `default.hypr.` and `omarchy.current.theme.` prefixes — a module required under
  any other name would be served from cache and quietly ignore every edit until
  Hyprland restarts. `dofile` re-reads the file on each `hyprctl reload`.
- **Trackpad gestures are `hl.gesture`, not a `gestures:` option.** The old
  `gestures:workspace_swipe = true` switch is gone — `hyprctl getoption
  gestures:workspace_swipe` answers `no such option`, which reads like the
  feature was dropped rather than moved. Since 0.55 each gesture is declared
  individually (`hl.gesture({ fingers = 3, direction = "horizontal", action =
  "workspace" })`) and the surviving `gestures:workspace_swipe_*` options only
  tune how the declared swipe behaves. One consequence of per-gesture
  declaration: a swipe on a different finger count is a separate registration,
  so covering both three and four fingers means two `hl.gesture` calls. Anything
  written for a pre-0.55 config, including most search results, is wrong here.
- **Rebinding a media key means re-stating its options.** `hl.unbind` +
  `o.bind` drops whatever `{ locked = true, repeating = true }` the Omarchy
  default carried. Without `locked` the volume keys go dead on the lock screen,
  and without `repeating` they fire once when held.
- **`hyprctl configerrors` really does validate the Lua config.** It reports
  unknown window-rule fields by name (`hl.window_rule: unknown field '...'`),
  so a clean run after `hyprctl reload` is a genuine check that every rule name
  survived the conversion, not just that the file parsed.
- **`hyprctl workspacerules` does not print `layout`.** It shows `monitor` and
  `default` and stops, so a per-workspace `layout = "master"` looks unset even
  when it is working. The layout a workspace actually ended up with is in
  `hyprctl workspaces -j` as `tiledLayout` — the direct answer, and it reports
  `dwindle` for a workspace whose rule never resolved just as plainly as for one
  that asked for dwindle, which is what makes the `lua:` prefix trap above
  survivable. Window geometry is the fallback: under the desktop config the
  master window on DP-1 is ~2536px wide and centered, while `general:layout` is
  still `dwindle`.
- **A workspace rule's `layout` applies even when the monitor it names is
  absent.** `monitor = "DP-1"` is a preference for where the workspace opens, not
  a condition on the rest of the rule, so `layout = "lua:custom_center"` on
  workspaces 1-5 followed this config onto a laptop that has no DP-1 at all: the
  workspaces fell back to `eDP-1` and took the ultrawide's centre-master layout
  with them. There is no per-monitor layout setting to express this properly
  (which is why the workspace ranges exist), so `hypr/monitors.lua` picks the
  machine first and emits only that machine's rules. It reads
  `/sys/class/drm/card*-eDP-1/status` to decide, because the kernel has that
  populated before Hyprland starts, unlike `hl.get_monitors()`, whose contents at
  config-parse time cannot be checked without restarting the session. Card
  numbering is not stable across boots, so the check loops over card indices
  rather than hardcoding `card2`.
- **Quattro dropped `omarchy-swayosd-client` and `satty`.** Volume feedback now
  goes through `omarchy-audio-output-volume raise|lower`. Screenshot annotation
  moved to `tensaku-edit`, so satty is no longer pulled in by Omarchy — but the
  `ALT + SHIFT + 4` binding still wants it, and `install-satty.sh` reinstalls it
  from `extra`. It is a repo package, not an AUR one, despite having been dropped
  from Omarchy's own dependencies.
- **strongSwan ignores the system CA store.** `update-ca-trust` is not enough:
  charon only trusts certificates in `/etc/swanctl/x509ca`. Without them the
  handshake fails with `no issuer certificate found` even though `trust list`
  shows the root as an anchor.
- **`swanctl` needs no sudo here.** charon creates `/run/charon.vici` as
  `root:root` mode 0660, so only the group blocks access. A systemd drop-in
  chgrps it to `wheel`, whose members can already become root. `swanctl
  --load-all` is the exception, it reads the rendered credentials under
  `/etc/swanctl` and still needs root.
- **An `EXIT` trap in a sourced script replaces the one in `install-all.sh`.**
  These scripts share a shell, and `install-vpn.sh` sets its own trap, so
  `install-all.sh` cannot rely on a trap to clean up after itself. Its sudo
  keep-alive loop therefore self-terminates on `kill -0 "$$"` instead.
- **A background sudo keep-alive does not survive this run.** `install-all.sh`
  asked for a second password around `install-php-pie.sh` — the first script with
  a sudo line in it after a long stretch that needs none, because yay skips sudo
  entirely when every package is already up to date. Refreshing sudo's timestamp
  in the background did not fix it, with either `sudo -n true` or `sudo -n -v`
  (only `-v` extends the timestamp at all; running a command just consumes the
  existing ticket). `install-all.sh` now uses `omarchy-sudo-passwordless` instead
  and does not rely on the credential cache. Why it held out is still unexplained,
  so re-check before trusting a keep-alive here again.
- **`omarchy-sudo-keepalive` has to be sourced, not run.** It kills its background
  loop from an `EXIT` trap, and executing it as a command reaches that trap
  immediately — so the loop is gone before it refreshes anything.
- **Removing a NOPASSWD rule takes the privilege that removes it.**
  `omarchy-sudo-passwordless` disables itself with `sudo rm` on the sudoers file
  followed by `sudo systemctl stop` on the expiry timer, and that second `sudo` has
  just lost the rule authorising it, so the tear-down asks for a password. Order
  matters more than it looks: `install-all.sh` does both in one `sudo` call and
  deletes the rule last.
- **Omarchy closes every window *before* it powers off, so no shutdown hook can
  see the session.** `omarchy-system-shutdown` arms poweroff as a 2s transient
  timer and *then* runs `omarchy-hyprland-window-close-all`; reboot and logout do
  the same. Anything observing at teardown -- an `ExecStop=`, a logind inhibitor --
  observes an empty window list. Shadowing the binary is not an option either:
  `/usr/share/omarchy/bin` is a symlink farm that sits ahead of `/usr/local/bin`
  on `PATH`, and `~/.local/bin` comes after `/usr/bin`. That leaves the menu's
  own action string, overridden in `~/.config/omarchy/extensions/omarchy-menu.jsonc`,
  as the only interception point that runs while the windows still exist. It is
  also why the tool is called `hypr-session` and not `omarchy-session`: anything
  Omarchy ever ships under that name would silently win.
- **A partial menu override blanks every field it omits, and a malformed one
  silently deletes the whole extension.** `MenuModel.js` `normalizeItem()` emits
  every key (empty string when absent) and `mergeMenuSources()` copies all of them
  over the default, so overriding only `action` on `system.shutdown` leaves a row
  labelled `system.shutdown` with no icon -- the file's own comment claims
  otherwise. Worse, `stripJsonc()` handles whole-line `//` comments only (no
  `/* */`, though trailing commas are fine) and `parseMenuJsonc()` catches the
  failure and returns `[]` with `printErrors: false`. One stray character drops
  every user menu row with nothing in the journal. `install-session.sh` therefore
  re-declares `icon` and `label` from the packaged file, and parses its own
  candidate before writing it.
- **A `graphical-session.target` unit's `ExecStop` races the compositor unless it
  says `After=wayland-wm@hyprland.desktop.service`.** A target automatically gains
  `After=` on everything in its `Wants=`, so with `PartOf=` and `WantedBy=` alone
  the unit and `wayland-wm@` are both merely "after `graphical-session.target`" on
  the way down, with no edge between them, and whether `hyprctl` still answers is
  a coin flip. `After=graphical-session.target` looks like the fix and is an
  ordering cycle, which systemd resolves by dropping an edge of its choosing. Also
  set `TimeoutStopSec=`: Omarchy caps the whole session teardown at 5s via a
  `user@.service` drop-in, but that drop-in does not reach units *inside* the
  manager, which would otherwise inherit 90s and hang the shutdown.
- **Every Chrome window of every profile shares one process, so a window cannot
  be attributed to a profile.** Chrome runs one browser process per
  *user-data-dir*, and `--profile-directory` only selects a profile inside it, so
  the flag on the process names whichever profile happened to start it. Launching a
  second profile while Chrome is up returns a window with the *original* pid and
  leaves the cmdline unchanged. Reading the flag per window therefore files every
  window under one profile and silently drops the rest from the save, which is
  exactly how two windows went missing after a reboot. `profile.last_active_profiles`
  in `~/.config/google-chrome/Local State` is the real source for which profiles
  have windows, and it updates as soon as one gains a window. The upside is that
  `--profile-directory=X --restore-last-session` works even when Chrome is already
  running: the invocation is forwarded to the live instance, which opens that
  profile and restores its own session.
- **Chrome collapses its whole argv into one blob, so the obvious way to read its
  profile finds nothing.** Every other app keeps a NUL-separated
  `/proc/<pid>/cmdline`, but Chrome rewrites its own for the process title. Scanning
  argv elements for `--profile-directory=` therefore matches nothing and, because
  Chrome omits that flag entirely for the default profile, every window reads as
  `Default` -- silently restoring the wrong profile. `hypr-session` falls back to
  searching the joined text, ending the value at the next ` --` because a profile
  directory contains a space (`Profile 1`).
- **`hyprctl dispatch` reports success no matter what; `hyprctl eval` does not.**
  A dispatch against a nonexistent address prints `ok` and exits 0, so no check may
  rely on its exit status -- assert on observed state instead. `hyprctl eval` is the
  exception: it exits 7 on a Lua error, which is what makes it worth using for the
  launch calls. (`hyprctl repl` is the one that prints a return value; `eval`
  swallows it.)
- **A window rule's `move` is monitor-relative, while `hyprctl clients`' `at` is
  global.** On a stacked two-monitor setup this is a 1440px difference and nothing
  warns about it: `move = { 100, 200 }` on DP-1, whose origin is `y=1440`, reports
  back as `at=[100,1640]`. The save side stores floating geometry as a fraction of
  the monitor and the restore emits `monitor_w`/`monitor_h` expressions, which also
  makes a desktop-saved session land sanely on the laptop panel.
- **Arrival order is tiling order.** Launching three windows into an empty
  `lua:custom_center` workspace one at a time puts the first in the centre master
  and the next two in the side quarters, every time -- `recalculate()` appends new
  addresses in `ctx.targets` order and `states` is empty at login. So the restore
  launches sequentially and waits for each window to map, and never replays pixel
  geometry for a tiled window. Which order to launch in is the subtle part: see
  the next two entries.
- **`uwsm-app` carries Hyprland's exec rules, despite being a FIFO client.**
  Reading the source suggests it cannot: `uwsm-app` writes to a pipe and
  `wayland-wm-app-daemon.service` spawns the app, so neither the PID chain nor the
  environment that `HL_EXEC_RULE_TOKEN` and the PPID walk depend on should reach
  it. Measured, it works anyway -- a window launched through it lands on the
  workspace the rule asked for. Worth knowing before "fixing" a working restore to
  use the slower `uwsm app`. Either form names the scope
  `app-Hyprland-<name>-<hex8>.scope`, so `-a <desktop-id>` is what makes the id
  survive into the next save.
- **The Omarchy menu launches apps through `gtk-launch`, which erases the desktop
  id.** A window started from the menu lands in
  `app-Hyprland-gtk\x2dlaunch-<hex>.scope` rather than `app-<id>-<pid>.scope`, so
  the launcher identity is simply gone -- verified on Sublime and PhpStorm, both of
  which were silently skipped by an `id:` matcher that looked correct, and would
  otherwise have been recorded with an unusable raw cmdline. `hypr-session`
  therefore falls back to matching an `id:` rule against the window class, which
  is what makes the allow-list work for anything opened the way these apps
  normally are.
- **Claude Code does not hold its transcript open, so a running session's id is
  not in `/proc`.** It appends and closes, and the id is not in the process's
  cmdline or environment either. What does work: the transcript lives at
  `~/.claude/projects/<slug>/<session-id>.jsonl`, where the slug is the session's
  cwd with every non-alphanumeric character replaced by a dash (so
  `~/.claude/skills` becomes `-home-koen--claude-skills`, double dash included),
  and the newest transcript in that directory is the live session. For the case
  that breaks -- two sessions in one directory -- the daemon puts one socket per
  live session at `/tmp/cc-daemon-<uid>/<id>/rv/<first-8-of-session-id>.sock`,
  which can be attributed to a terminal by matching `/proc/net/unix` inodes
  against its descendants' file descriptors. That part is undocumented internals
  and degrades to the newest transcript if it ever changes.
- **`custom_center`'s per-workspace state is recoverable by inverting its own
  geometry.** `custom-layout.lua` keeps `masters` and `window_order` in a
  module-local table with no persistence, so there is nothing on disk to read --
  but the placement is invertible: windows whose horizontal centre falls in the
  middle half of the monitor are the masters, which gives the master count,
  ordered left to right, followed by the left-quarter slaves top to bottom and
  then the right-quarter ones. Classifying on a fraction of the monitor rather
  than against the workspace's usable area means gaps and the bar's reserved strip
  need no accounting. Verified against a live desktop: it reproduced `masters = 2`
  on one workspace and `1` on another, with the right window in every slot.
- **Creation order is not render order, so restoring by age demotes a promoted
  master.** `swapwithmaster` reorders `window_order` while changing nothing
  observable about a window's age, so the master is routinely the *newest* window
  -- on the live desktop PhpStorm held master slot 1 while being the last window
  opened. Launching in `stableId` order would have put it in a side quarter. The
  saved slot index is what the restore replays instead.
- **`addmaster` promotes the focused window into the slot it creates.** So
  replaying a master count is not simply dispatching it N-1 times: whatever
  happens to be focused gets pulled into each new slot, scrambling the order just
  rebuilt. Focus the window that belongs in slot `i` first and the layout skips the
  swap, because it only swaps when the target is not already sitting there.
- **Post-hoc placement must skip multi-instance classes.** Two windows of one
  class are indistinguishable from outside, so "move a foot to the workspace this
  saved foot was on" is as likely to drag an unrelated terminal across the desktop
  -- observed, on the terminal this was being developed in. For the same reason the
  already-running count for a `mode=multi` app has to be per workspace: one live
  terminal elsewhere otherwise suppresses a launch on a workspace that had none.
