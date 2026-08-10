#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BRANDING_DIR="$HOME/.config/omarchy/branding"

cp $SCRIPT_DIR/branding/screensaver.txt $BRANDING_DIR/screensaver.txt

echo "Installed custom branded screensaver"