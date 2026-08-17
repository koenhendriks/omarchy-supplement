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
| `install-hypridle-config.sh` | Idle timings: screensaver 2.5 min, lock 30 min, suspend 40 min |
| `install-hyprland-overrides.sh` | Adds `dofile()` lines for `hypr/*.lua` |
| `install-claude-waybar.sh` | `claudebar`, the Claude usage waybar module |
| `install-waybar-config.sh` | Links `waybar/config.jsonc`, merges `waybar/style.css` |
| `install-mako-config.sh` | Links `mako/config` over the theme's notification config |
| `hypr/` | Hyprland override modules in Lua (bindings, monitors, windows, input) |
| `waybar/` | Full waybar config, VPN status script, style fragment |
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

**Waybar** has no equivalent include mechanism for a whole config, so
`config.jsonc` is symlinked over the existing one (the original is kept as
`config.jsonc.bak`). Because it is a symlink, edits in this repo are live,
just restart waybar and they apply.

**Mako** notifications are centered along the top edge (`anchor=top-center`).
Omarchy points `~/.config/mako/config` at the *current theme's* `mako.ini`, which
`omarchy theme set` deletes and regenerates from a template — so editing that
file loses the change on the next theme switch. `mako/config` here `include`s it
and overrides afterwards, keeping the theme's colours while the anchor sticks.
Only Omarchy's install-time `theme.sh` recreates that symlink, so this survives
theme changes.

**Hypridle** gets a longer leash than the stock 2.5 min screensaver / 5 min lock:
the screensaver runs for 27.5 min, the screen locks at 30 min of idle, and the
machine suspends at 40 min. `install-hypridle-config.sh` keeps Omarchy's
`general{}` block verbatim — `lock_cmd`, `before_sleep_cmd` and `inhibit_sleep`
are what make suspend safe, and are worth inheriting — and replaces only the
listeners, as a marked block. The timings live in the script as three wall-clock
constants; the timeouts in the file are derived from them.

hypridle has no include mechanism that helps here. It does support `source =`, but
listeners are purely additive: a sourced fragment can add a suspend listener and
cannot raise the stock 5 min lock, which would then still fire. Hence the whole
listener section is generated. **Editing the timings requires re-running
`install-hypridle-config.sh`**, and so does an `omarchy refresh hypridle`, which
puts the defaults back.

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
- **The screensaver resets hypridle's idle timer.** `omarchy-launch-screensaver`
  warps the cursor between monitors with `hyprctl dispatch focusmonitor`, and that
  pointer motion counts as activity. So every listener that fires after it is
  timed from the screensaver's own timeout, not from the start of idle — a lock
  listener at 1800 s locks 32.5 min in, not 30. Omarchy's default config works
  around it with a hardcoded "half + 2s margin" comment;
  `install-hypridle-config.sh` subtracts the offset instead, so its three
  constants can stay wall-clock. Locking does *not* reset the timer, which is why
  the suspend listener can be timed from the same baseline.
- **`omarchy-refresh-config` writes through a symlink.** It installs defaults with
  `cp -f`, which follows the destination symlink, so the waybar trick of pointing
  `~/.config` at a file in this repo would have `omarchy refresh hypridle`
  overwrite the repo copy rather than the one in `~/.config`. `hypridle.conf` is
  therefore generated as a plain file. Worth remembering before symlinking any
  other config that has an `omarchy refresh` for it.
- **`hypr/*.lua` is globbed into `hyprland.lua`.** `install-hyprland-overrides.sh`
  appends a `dofile()` line for every `.lua` in `hypr/`, so config for a *different*
  hypr daemon cannot be parked there: a `listener{}` block reaching Hyprland is a
  config error, not an idle timer. That is why the hypridle listeners are a heredoc
  in the script instead of a file next to `bindings.lua`.
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
