#!/bin/bash

# Install all packages in order
. ./install-browser.sh
. ./remove-default-browsers.sh
. ./remove-webapps.sh
. ./install-glab.sh
. ./install-teams.sh
. ./install-outlook.sh
. ./install-yaak.sh
. ./install-le-ca.sh
. ./install-openvpn.sh
. ./install-strongswan.sh
. ./install-vpn.sh
. ./install-hyprland-overrides.sh
. ./install-claude-waybar.sh
. ./install-waybar-config.sh
