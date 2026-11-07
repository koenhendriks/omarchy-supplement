#!/bin/bash

set -e

# PIE used to be the release phar dropped in /usr/local/bin, which pacman does not
# track and which comes before /usr/bin on PATH, so a leftover copy would keep
# shadowing the package.
if [ -f /usr/local/bin/pie ] && ! pacman -Qo /usr/local/bin/pie >/dev/null 2>&1; then
    echo "Found an unpackaged /usr/local/bin/pie that shadows the AUR package"
    echo "Remove it with: sudo rm /usr/local/bin/pie"
fi

echo "Installing PIE"
omarchy-pkg-aur-add pie

echo "PIE setup complete!"
