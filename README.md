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
| `install-hyprland-overrides.sh` | Adds `source =` lines for `hypr/*.conf` |
| `install-claude-waybar.sh` | `claudebar`, the Claude usage waybar module |
| `install-waybar-config.sh` | Links `waybar/config.jsonc`, merges `waybar/style.css` |
| `install-mako-config.sh` | Links `mako/config` over the theme's notification config |
| `hypr/` | Hyprland override fragments (bindings, monitors, windows, input) |
| `waybar/` | Full waybar config, VPN status script, style fragment |
| `mako/` | Notification overrides layered on top of the current theme |
| `vpn/` | VPN profiles and certificates -> see [vpn/README.md](vpn/README.md) |

## Config overrides

**Hyprland** keeps its own config; the installer only appends a `source =` line
per file in `hypr/`, so those fragments stay authoritative and Omarchy's defaults
are never edited.

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
