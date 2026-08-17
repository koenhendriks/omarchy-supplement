# omarchy-supplement

Personal additions on top of [Omarchy](https://omarchy.org): extra packages, a
few Hyprland and waybar overrides, and two work VPNs moved off NetworkManager.

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
| `install-omarchy-notifications.sh` | Rebuilds the `<user>.notifications` plugin: toasts at top-centre |
| `install-omarchy-shell.sh` | Merges `omarchy/shell-bar.json` into the Quickshell bar layout |
| `install-claude-waybar.sh` | `claudebar`, the Claude usage waybar module |
| `install-waybar-config.sh` | Links `waybar/config.jsonc`, merges `waybar/style.css` |
| `install-mako-config.sh` | Links `mako/config` over the theme's notification config |
| `hypr/` | Hyprland override modules in Lua (bindings, monitors, windows, input) |
| `omarchy/` | Quickshell bar layout fragment merged into `shell.json` |
| `waybar/` | Full waybar config, VPN status script, style fragment (unused) |
| `mako/` | Notification overrides layered on top of the current theme |
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
| `cpu` | `cpu`, a custom command module (no native equivalent) |

`waybar/` is left in place but nothing reads it any more.

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

**Waybar** has no equivalent include mechanism for a whole config, so
`config.jsonc` is symlinked over the existing one (the original is kept as
`config.jsonc.bak`). Because it is a symlink, edits in this repo are live,
just restart waybar and they apply.

**Notifications** are Quickshell's now, not mako's, and they ship pinned to the
top-right corner with no setting to move them (`Service.qml`: "Toasts are fixed
to the top-right corner"). `install-omarchy-notifications.sh` clones the plugin
and changes only the horizontal alignment, so toasts sit at top-centre the way
mako's `anchor=top-center` put them. The top margin still comes from
`popupPlacement()`, so a toast keeps clearing a top bar by the same clearance.

Cloning a plugin whose kind is not a bar widget is enough to take over from the
built-in one: the registry adds the source to `disabledPlugins` and records
`cloneSourceRestores`, so exactly one notification service runs and disabling the
clone brings the original back.

**Mako** is no longer used. The section below is kept for the record.

**Mako** notifications are centered along the top edge (`anchor=top-center`).
Omarchy points `~/.config/mako/config` at the *current theme's* `mako.ini`, which
`omarchy theme set` deletes and regenerates from a template — so editing that
file loses the change on the next theme switch. `mako/config` here `include`s it
and overrides afterwards, keeping the theme's colours while the anchor sticks.
Only Omarchy's install-time `theme.sh` recreates that symlink, so this survives
theme changes.

**Idle** is no longer overridden here. Omarchy 4 (quattro) removed hypridle
entirely; idle timings now live in `~/.config/omarchy/shell.json` under `idle`,
and stay at Omarchy's defaults.

`style.css` is the exception: it has to keep Omarchy's rules and the theme
`@import` that defines `@background`, so the fragment is merged in as a marked
block at the end of the file instead. **Editing `waybar/style.css` requires
re-running `install-waybar-config.sh`.**

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
  when `exec` is non-empty — so a static icon with an `onClick` is a valid
  module with no polling at all. That is what the `cpu` entry is: waybar's
  `cpu` module was also icon-only, a btop launcher rather than a readout.
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
  `cp -f`, which follows the destination symlink, so the waybar trick of pointing
  `~/.config` at a file in this repo would have an `omarchy refresh` overwrite the
  repo copy rather than the one in `~/.config`. Any config that has an
  `omarchy refresh` for it should be generated as a plain file, not symlinked.
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
