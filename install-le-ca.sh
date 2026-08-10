#!/bin/bash

set -e

ANCHORS=/usr/share/ca-certificates/trust-source/anchors

# Sandwave's IKEv2 gateway presents a Let's Encrypt chain anchored at the newer
# ISRG Root YR. -f makes curl fail loudly instead of saving an error page, -L
# follows redirects.
sudo curl -fsSL -o "$ANCHORS/root-yr.pem" https://letsencrypt.org/certs/gen-y/root-yr.pem
sudo curl -fsSL -o "$ANCHORS/root-yr-by-x1.pem" https://letsencrypt.org/certs/gen-y/root-yr-by-x1.pem
sudo curl -fsSL -o "$ANCHORS/isrgrootx1.pem" https://letsencrypt.org/certs/isrgrootx1.pem

sudo update-ca-trust

echo "Let's Encrypt CAs added to the system trust store"
echo "Note: strongSwan ignores this store; install-vpn.sh copies the roots into"
echo "/etc/swanctl/x509ca separately"
