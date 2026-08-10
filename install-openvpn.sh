#!/bin/bash

set -e

yay -S --noconfirm --needed openvpn3

# The config manager runs as the openvpn user (see the D-Bus service file) but
# the package ships its --state-dir as root:root 0755, so --persistent imports
# silently fail to reach disk and every profile disappears as soon as the
# service idles out or the machine reboots. 0700 because the persisted profiles
# contain the inlined private keys and credentials.
sudo install -d -o openvpn -g openvpn -m 700 /var/lib/openvpn3/configs

echo "openvpn3 installed"
ls -ld /var/lib/openvpn3/configs
