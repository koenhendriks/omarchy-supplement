# VPN profiles

Two connections, two different protocols, two different clients. Both are set up
by `../install-vpn.sh`, which reads the credentials from `../.env`.

## MassMarket — OpenVPN

Imported into openvpn3, which stores a *snapshot* of the profile: editing the `.ovpn` does
nothing until you re-run `install-vpn.sh` to re-import it.

    openvpn3 session-start --config MassMarket
    openvpn3 session-manage --config MassMarket --disconnect

The certificates in `certs/` are inlined at import time, so that directory has to
stay put. The server pushes compression, which openvpn3 refuses by default and
which can only be allowed through a profile override, not a directive in the
`.ovpn` — `install-vpn.sh` applies it after each import.


## Sandwave — IKEv2/IPsec

Not OpenVPN. The NetworkManager profile used the strongswan plugin
(`service-type=org.freedesktop.NetworkManager.strongswan`, `method=eap`), so
there is no `.ovpn` equivalent. `Sandwave.swanctl.conf.template` is the
translation; `install-vpn.sh` substitutes the credentials from `.env` and writes
it to `/etc/swanctl/conf.d/sandwave.conf`.

    swanctl --initiate --child Sandwave
    swanctl --terminate --ike Sandwave    # --child only drops the tunnel,
                                          # leaving the IKE_SA up
    swanctl --list-sas                    # what is currently connected

The gateway narrows the negotiated traffic selectors to a fixed set of ~12 hosts,
so this tunnel is split by nature — there is nothing to configure for that, and
`remote_ts = 0.0.0.0/0` in the template is only what gets *requested*.

Traffic reaches those hosts only when its source address is the virtual IP
(`10.254.0.x`), which is what the xfrm policy matches. That depends on charon's
routes in table 220 being reachable via an `ip rule`; without the rule the tunnel
reports ESTABLISHED, moves 0 bytes, and requests silently go out unencrypted from
the LAN address. Check with `ip rule show | grep 220` and
`swanctl --list-sas` byte counters, not just the SA state.

The gateway presents a Let's Encrypt certificate. Note that strongSwan **ignores
the system CA bundle** — `update-ca-trust` is not enough. charon only trusts CA
certificates in `/etc/swanctl/x509ca`, so `install-vpn.sh` copies the ISRG roots
fetched by `../install-le-ca.sh` into that directory. Without it the handshake
fails with `no issuer certificate found` even though `trust list` shows the root
as an anchor.
