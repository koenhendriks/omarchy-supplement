#!/bin/bash

set -e

echo "Installing nmap"
yay -S --noconfirm --needed nmap

echo "Nmap setup complete!"
