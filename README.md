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
| `install-bitwarden.sh` | Bitwarden desktop and CLI |
| `install-phpstorm.sh` | PhpStorm and its bundled JRE |
| `install-nextcloud.sh` | Nextcloud client, plus sync exclusions for agent scratch and lock files |
| `install-glab.sh` | GitLab CLI |
| `install-teams.sh` | Teams for Linux |
| `install-outlook.sh` | Outlook as an Omarchy webapp |
| `install-yaak.sh` | Yaak, with a WebKitGTK workaround in its desktop entry |
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
| `install-omarchy-shell.sh` | Merges `omarchy/shell-bar.json` into the Quickshell bar layout |
| `install-omarchy-notification-plugin.sh` | Adds the third-party notification centre, patched to find the cloned service |
| `lib/omarchy-plugin.sh` | Shared clone/patch/restart helpers for the plugin installers |
| `hypr/` | Hyprland override modules in Lua (bindings, monitors, windows, input) |
| `omarchy/` | Quickshell bar layout fragment, plus the scripts its command modules run |
| `vpn/` | VPN profiles and certificates -> see [vpn/README.md](vpn/README.md) |

## Config overrides

**Hyprland** keeps its own config; the installer only appends a `dofile()` line
per file in `hypr/` to `~/.config/hypr/hyprland.lua`, so those modules stay
authoritative and Omarchy's defaults are never edited. They load last, after
Omarchy's defaults and after `~/.config/hypr/*.lua`, so they win.

Omarchy 4 (quattro) moved Hyprland from `.conf` to Lua. The overrides here use
Omarchy's own helpers — `o.bind` for keys, `o.window` for window rules — rather
than raw `hl.*` calls, so they keep the descriptions that
`omarchy menu keybindings --print` renders and pick up whatever `o.bind` learns
to do next.

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

`status` and `toggle` are subcommands of one script deliberately: both have to
decide whether a VPN is up, and two copies of that check would eventually
disagree, giving a toggle that connects while the bar reads connected. A
standalone `~/.local/bin/vpn-toggle` used to hold the toggle half; its logic was
absorbed here and the script removed, so the bar has no dependency outside a
fresh clone of this repo.

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

**Idle** is no longer overridden here. Omarchy 4 (quattro) removed hypridle
entirely; idle timings now live in `~/.config/omarchy/shell.json` under `idle`,
and stay at Omarchy's defaults.

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
- **There is no per-app mute anywhere in the shell.** `notifications.json` is
  `{version, dnd}` and that is the whole of it; the only per-app list in
  `NotificationLogic.js` is `isEphemeralApp()`, hardcoded to `notify-send` and
  `omarchy-action`, and it decides recording, not display. Muting one noisy app
  means patching the service, which means cloning it — hence the hole above.
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
  when it is working. Check the window geometry instead — under this config the
  master window on DP-1 is ~2536px wide and centered, while `general:layout` is
  still `dwindle`.
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
