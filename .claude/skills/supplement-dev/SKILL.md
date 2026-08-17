---
name: supplement-dev
description: Conventions and verification steps for developing the omarchy-supplement repo. Use when adding or changing any install-*.sh script, the hypr/ or omarchy/ overrides, or the MassMarket (openvpn3) and Sandwave (strongSwan) VPN setup.
---

# Developing omarchy-supplement

Personal Omarchy supplement: package installers, Hyprland (Lua) and Quickshell
shell overrides, and two work VPNs moved off NetworkManager.

## Read first

`README.md` has a section called **"Things that cost time to work out"**, and
`vpn/README.md` covers the VPN conversions. Read the relevant one before changing
VPN or shell behaviour. Each entry there was expensive to discover and presents
as a symptom that points somewhere else — a profile that "vanishes", a VPN that
connects and then dies one log line later, a CA that `trust list` says is trusted
but strongSwan rejects. Do not rediscover these from scratch.

When you learn something equally non-obvious, add it to that section and leave a
comment at the line it explains.

## install-*.sh conventions

Follow `install-hyprland-overrides.sh` and `install-omarchy-shell.sh` — they are
the reference style.

```bash
#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ ! -d "$SOME_TARGET" ]; then
    echo "Not found at $SOME_TARGET"
    echo "Run ./install-something.sh first"
    exit 1
fi

echo "Doing the thing"
...
echo "Thing setup complete!"
```

- Guard clauses first: check preconditions, `echo` a human-readable message that
  names the missing path and the script that provides it, then `exit 1`.
- `echo` each action as it happens. Silence is indistinguishable from failure.
- Register the script in `install-all.sh` in dependency order — packages before
  the config that uses them.
- `chmod +x` the new script.

**These scripts are sourced, not executed.** `install-all.sh` runs
`. ./install-foo.sh`, so:

- Never `exit 0` at the end — it terminates the entire run.
- If you `cd`, restore `$PWD` before the script ends, or the next script sourced
  by relative path is not found. `install-vpn.sh` shows the pattern.
- An `EXIT` trap does **not** fire when the sourced script finishes; it fires when
  the whole `install-all.sh` run ends. Too late for cleanup that the next script
  depends on.

## Idempotency

Every script must be safe to re-run; `install-all.sh` is the normal entry point.
Patterns already in use, prefer them over inventing new ones:

- `yay -S --noconfirm --needed` for packages.
- `grep -Fxq` before appending a line (`install-hyprland-overrides.sh`).
- Back up to `*.bak` only when no backup exists, so the pristine original is
  never overwritten by a second run.
- Merge into an existing config rather than overwriting it
  (`install-omarchy-shell.sh` replaces only the `bar` key of `shell.json`, leaving
  `idle`, `plugins` and the bar's own drag-to-reorder writes alone).
- `openvpn3` has no in-place profile edit: remove, then re-import.

Verify by running the script twice and confirming the second run reports no
changes and the file is byte-identical.

## Secrets

- A new secret goes in three places: `.env`, `.env.example` (with an empty
  value), and a `require VAR` line in `install-vpn.sh`.
- Never commit `.env`, `vpn/certs/`, `vpn/*.nmconnection`, or `vpn/*.auth`. All
  are gitignored — keep it that way.
- Render credential files with `umask 077` or `install -m 600`, and delete
  temporary ones once consumed.
- Redact secrets when showing rendered output.

## Verification

Do not report success on reasoning alone. What is actually runnable:

| Change | Check |
| --- | --- |
| Any script | `bash -n script.sh`, then run it twice |
| `omarchy/shell-bar.json` | Parse it, then run the installer twice and confirm the second run reports no change |
| A cloned shell plugin | `omarchy restart shell` (a hot reload serves stale compiled QML), then `hyprctl layers` for the surface and `journalctl --user` for QML errors |
| `omarchy/bar/vpn` | Exercise all four states; stubbing `openvpn3`/`swanctl` on `PATH` covers the branches without raising a real tunnel |
| MassMarket end to end | `ssh root@visp` — that host sits behind pushed route `185.175.200.0/22`, so it only resolves over the tunnel |
| Sandwave | `swanctl --list-sas` shows `Sandwave: #N, ESTABLISHED` |

VPN control, none of which needs sudo:

    openvpn3 session-start --config MassMarket
    openvpn3 session-manage --config MassMarket --disconnect
    swanctl --initiate --child Sandwave
    swanctl --terminate --ike Sandwave

## sudo

`sudo` needs an interactive password in agent sessions — `sudo -n` fails. Any
step touching `/etc`, `/var/lib`, or systemd cannot be run or verified; hand the
user the exact command and say plainly that it is untested. Do not describe an
unrun step as done.

Read-only checks that work without sudo: `ls -ld`, `trust list`,
`openvpn3 configs-list`, `swanctl --list-sas`, `journalctl` (user and system),
`pacman -Ql`, and `strings` on a binary to confirm an option is really supported
rather than merely accepted and stored.

## Do not

- Reintroduce `nmcli` for either VPN. No NetworkManager VPN profiles exist.
- Hand-edit `~/.config/omarchy/plugins/<user>.bar` or `<user>.notifications` — both
  are derived clones, rebuilt from the packaged plugin on every installer run.
  Change the patches in the installer instead.
- Edit anything under `~/.local/share/omarchy/`. Overrides belong here.
- Add Claude or Anthropic attribution to commits, MRs, or changelog entries.
