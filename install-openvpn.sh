#!/bin/bash

set -e

omarchy-pkg-aur-add openvpn3

# openvpn3 comes from the AUR, so it is linked against whatever sonames were on
# disk the day it was built. A repo dependency bumping its soname leaves the
# binary unable to start -- jsoncpp 1.9.8 replaced libjsoncpp.so.26 with .27 and
# openvpn3 died with "error while loading shared libraries" -- and pacman sees
# none of it, because the versioned `jsoncpp>=0.10.5` dependency is still
# satisfied. `omarchy-pkg-aur-add` above then finds the package installed and
# skips it, so the break survives every re-run until it is rebuilt by hand.
#
# Ask the binary rather than the package database, which is the only place the
# breakage is visible.
#
# The rebuild stays raw yay: no Omarchy helper expresses --rebuild, and
# omarchy-pkg-aur-add would refuse the job anyway, since its whole guard is that
# the package is already there.
if ldd /usr/bin/openvpn3 2>/dev/null | grep -q "not found"; then
    echo "openvpn3 is linked against libraries that are no longer installed:"
    ldd /usr/bin/openvpn3 2>/dev/null | grep "not found" | sed 's/^/    /'
    echo "Rebuilding openvpn3 against the libraries currently installed"
    yay -S --noconfirm --rebuild openvpn3

    if ldd /usr/bin/openvpn3 2>/dev/null | grep -q "not found"; then
        echo "openvpn3 is still missing libraries after a rebuild:"
        ldd /usr/bin/openvpn3 2>/dev/null | grep "not found" | sed 's/^/    /'
        echo "Fix the package before continuing; install-vpn.sh cannot import profiles without it"
        exit 1
    fi
fi

# The config manager runs as the openvpn user (see the D-Bus service file) but
# the package ships its --state-dir as root:root 0755, so --persistent imports
# silently fail to reach disk and every profile disappears as soon as the
# service idles out or the machine reboots. 0700 because the persisted profiles
# contain the inlined private keys and credentials.
sudo install -d -o openvpn -g openvpn -m 700 /var/lib/openvpn3/configs

echo "openvpn3 installed"

# Through sudo because the package owns /var/lib/openvpn3 as openvpn:openvpn 0750
# and this user cannot traverse it. Without sudo the stat fails, and under set -e
# that takes install-all.sh down on what is only meant to be a confirmation line.
sudo ls -ld /var/lib/openvpn3/configs
