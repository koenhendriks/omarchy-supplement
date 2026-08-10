#!/bin/bash

# Waybar status for the two VPNs. Neither is a NetworkManager connection any
# more, and they use different clients, so the check depends on which one we are
# asked about: MassMarket is OpenVPN (openvpn3), Sandwave is IKEv2 (strongSwan).

VPN_NAME="$1"

# A session/SA can exist while still connecting or after an auth failure, so
# both checks require the established state rather than mere existence.
openvpn3_connected() {
    command -v openvpn3 >/dev/null || return 1
    openvpn3 sessions-list 2>/dev/null | awk -v name="$1" '
        /^ *Config name:/ { cfg = $3 }
        /^ *Status:/ && cfg == name && /Client connected/ { found = 1 }
        END { exit found ? 0 : 1 }
    '
}

swanctl_connected() {
    command -v swanctl >/dev/null || return 1
    swanctl --list-sas 2>/dev/null | grep -qE "^$1: #[0-9]+, ESTABLISHED"
}

case "$VPN_NAME" in
    MassMarket) openvpn3_connected "$VPN_NAME" ;;
    Sandwave)   swanctl_connected "$VPN_NAME" ;;
    *)          false ;;
esac

if [ $? -eq 0 ]; then
    echo '{"text": "", "class": "connected", "tooltip": "'"$VPN_NAME"': Connected"}'
else
    echo '{"text": "", "class": "disconnected", "tooltip": "'"$VPN_NAME"': Disconnected"}'
fi
