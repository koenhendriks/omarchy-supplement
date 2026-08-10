#!/bin/bash

# Install all packages in order
. ./install-browser.sh
. ./remove-default-browsers.sh
. ./remove-webapps.sh
. ./remove-preinstalled.sh
. ./install-screensaver.sh
. ./install-bind.sh
. ./install-bitwarden.sh
. ./install-phpstorm.sh
. ./install-dev-laravel.sh
. ./install-yarn.sh
. ./install-nextcloud.sh
. ./install-glab.sh
. ./install-whatsapp.sh
. ./install-telegram.sh
. ./install-teams.sh
. ./install-outlook.sh
. ./install-slack.sh
. ./install-yaak.sh
. ./install-chrome-profiles.sh
. ./install-le-ca.sh
. ./install-openvpn.sh
. ./install-strongswan.sh
. ./install-vpn.sh
. ./install-hyprland-overrides.sh
. ./install-claude-waybar.sh
. ./install-waybar-config.sh
. ./install-mako-config.sh
