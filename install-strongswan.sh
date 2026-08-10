#!/bin/bash

set -e

yay -S --noconfirm --needed strongswan

# swanctl talks to charon over /run/charon.vici, which charon creates as
# root:root 0660. The mode already allows group access, so only the group needs
# changing for swanctl to work without sudo. wheel members can already become
# root via sudo, so this grants no new privilege.
#
# The leading - keeps a missing socket from failing the unit. The socket is
# guaranteed to exist by ExecStartPost time: the packaged unit is Type=notify
# and its own ExecStartPost runs swanctl --load-all, which needs vici too.
sudo install -d -m 755 /etc/systemd/system/strongswan.service.d
sudo install -m 644 /dev/stdin /etc/systemd/system/strongswan.service.d/vici-group.conf <<'EOF'
[Service]
ExecStartPost=-/usr/bin/chgrp wheel /run/charon.vici
ExecStartPost=-/usr/bin/chmod 660 /run/charon.vici
# charon installs its routes into table 220 but that table is dead weight
# without an ip rule pointing at it: the lookup falls through to the main table,
# picks the LAN address as source instead of the virtual IP, and the packets miss
# the xfrm policy and leave the machine unencrypted. The rule is supposed to be
# created by charon itself and was observed missing, so add it if it is absent.
ExecStartPost=-/usr/bin/sh -c 'ip rule show | grep -q "lookup 220" || ip rule add priority 220 table 220'
EOF

# Ask charon explicitly for the table and priority it is meant to default to,
# rather than relying on the build-time defaults.
sudo install -m 644 /dev/stdin /etc/strongswan.d/99-omarchy-supplement.conf <<'EOF'
charon {
    install_routes = yes
    routing_table = 220
    routing_table_prio = 220
}
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now strongswan.service
sudo systemctl restart strongswan.service

echo "strongSwan installed"
ls -l /run/charon.vici
