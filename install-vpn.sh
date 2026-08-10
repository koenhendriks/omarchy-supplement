#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VPN_DIR="$SCRIPT_DIR/vpn"
ENV_FILE="$SCRIPT_DIR/.env"

if ! command -v openvpn3 >/dev/null; then
    echo "openvpn3 not found"
    echo "Run ./install-openvpn.sh first"
    exit 1
fi

if [ ! -f "$ENV_FILE" ]; then
    echo ".env not found at $ENV_FILE"
    echo "Copy .env.example to .env and fill in the VPN secrets first"
    exit 1
fi

set -a
# shellcheck disable=SC1090
. "$ENV_FILE"
set +a

require() {
    if [ -z "${!1}" ]; then
        echo "$1 is not set in $ENV_FILE"
        exit 1
    fi
}

require VPN_MASSMARKET_USERNAME
require VPN_MASSMARKET_PASSWORD
require VPN_SANDWAVE_USERNAME
require VPN_SANDWAVE_PASSWORD

# openvpn3 resolves ca/cert/key/auth-user-pass paths relative to the working
# directory and inlines them into the stored profile, so import from vpn/.
# install-all.sh sources this script and then sources the next one by relative
# path, so the working directory has to be put back before we are done.
ORIGINAL_PWD="$PWD"
cd "$VPN_DIR"

# Credentials only need to exist for the duration of the import
AUTH_FILE="$VPN_DIR/MassMarket.auth"
cleanup() {
    rm -f "$AUTH_FILE"
}
trap cleanup EXIT

(umask 077 && printf '%s\n%s\n' "$VPN_MASSMARKET_USERNAME" "$VPN_MASSMARKET_PASSWORD" > "$AUTH_FILE")

shopt -s nullglob
PROFILES=("$VPN_DIR"/*.ovpn)
shopt -u nullglob

if [ ${#PROFILES[@]} -eq 0 ]; then
    echo "No .ovpn profiles found in $VPN_DIR"
    exit 1
fi

for profile in "${PROFILES[@]}"; do
    name="$(basename "$profile" .ovpn)"

    # Re-importing is how you update a profile; openvpn3 has no in-place edit
    if openvpn3 config-manage --config "$name" --exists >/dev/null 2>&1; then
        echo "Removing existing openvpn3 profile $name"
        openvpn3 config-remove --config "$name" --force >/dev/null
    fi

    echo "Importing $name"
    openvpn3 config-import --config "$profile" --name "$name" --persistent >/dev/null

    # Both servers push compression, which openvpn3 refuses by default and then
    # tears the session down ("Compression Error: server pushed compression
    # settings that are not allowed"). This only works as an override; the
    # equivalent directive inside the .ovpn is parsed but ignored. asym accepts
    # compression downstream without compressing upstream, matching what
    # NetworkManager's comp-lzo=no-by-default did.
    openvpn3 config-manage --config "$name" --allow-compression asym >/dev/null
done

# Restored here rather than in the EXIT trap: when install-all.sh sources this
# script the trap does not fire until that whole run ends, which is too late for
# the next script it sources by relative path.
cd "$ORIGINAL_PWD"

# Sandwave is IKEv2/IPsec (NetworkManager strongswan plugin), not OpenVPN, so it
# goes to strongSwan instead of openvpn3. swanctl only reads /etc, hence sudo.
SWAN_TEMPLATE="$VPN_DIR/Sandwave.swanctl.conf.template"
SWAN_TARGET="/etc/swanctl/conf.d/sandwave.conf"

ANCHORS=/usr/share/ca-certificates/trust-source/anchors
SWAN_CA_DIR=/etc/swanctl/x509ca

if command -v swanctl >/dev/null; then
    # charon does not read the system CA bundle: swanctl only trusts CA certs
    # found in /etc/swanctl/x509ca, so update-ca-trust alone leaves the gateway
    # certificate unverifiable ("no issuer certificate found").
    for ca in root-yr.pem isrgrootx1.pem; do
        if [ ! -f "$ANCHORS/$ca" ]; then
            echo "$ANCHORS/$ca not found"
            echo "Run ./install-le-ca.sh first"
            exit 1
        fi
        sudo install -D -m 644 "$ANCHORS/$ca" "$SWAN_CA_DIR/$ca"
    done
    echo "Installed Let's Encrypt roots into $SWAN_CA_DIR"

    echo "Rendering $SWAN_TARGET"
    sudo install -d -m 700 /etc/swanctl/conf.d
    envsubst '$VPN_SANDWAVE_USERNAME $VPN_SANDWAVE_PASSWORD' < "$SWAN_TEMPLATE" \
        | sudo install -m 600 /dev/stdin "$SWAN_TARGET"
    sudo swanctl --load-all >/dev/null
else
    echo "swanctl not found, skipping Sandwave"
    echo "Run ./install-strongswan.sh first"
fi

echo "VPN profiles setup complete!"
echo "Connect to MassMarket with:       openvpn3 session-start --config MassMarket"
echo "Connect to Sandwave with:         swanctl --initiate --child Sandwave"
