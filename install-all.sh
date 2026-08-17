#!/bin/bash

# Sudo, once, for the whole run. omarchy-sudo-passwordless drops a NOPASSWD rule in
# /etc/sudoers.d and arms a systemd timer to delete it again.
#
# That timer is what makes this safe to do from a script. A guard clause in any
# sourced script can `exit 1` and take the whole run with it, skipping the
# tear-down at the bottom of this file and the rule still expires on its own.
SUDO_MINUTES=5
SUDO_NOPASSWD_FILE="/etc/sudoers.d/99-omarchy-nopasswd-$USER"
SUDO_NOPASSWD_WAS_ENABLED=false

# Checked by looking for the file, not with `sudo -n true`: a cached credential or
# an unrelated NOPASSWD rule would make that lie. This is the one password prompt.
if sudo test -f "$SUDO_NOPASSWD_FILE"; then
    SUDO_NOPASSWD_WAS_ENABLED=true
    echo "Passwordless sudo is already on, extending it to $SUDO_MINUTES minutes for this run"
else
    echo "Turning passwordless sudo on for $SUDO_MINUTES minutes so the run does not stop to ask"
fi

omarchy-sudo-passwordless "$SUDO_MINUTES"

# `sudo -n` so that declining the confirmation above lands here instead of asking
# for the password a second time on the way out.
if ! sudo -n test -f "$SUDO_NOPASSWD_FILE" 2>/dev/null; then
    echo "Passwordless sudo is not active, so this run would keep stopping for a password"
    echo "Re-run and confirm the prompt, or raise timestamp_timeout yourself"
    exit 1
fi

# Install all packages in order
. ./copy-resources.sh
. ./install-snap-pac.sh
. ./install-browser.sh
. ./remove-default-browsers.sh
. ./remove-webapps.sh
. ./remove-preinstalled.sh
. ./install-cronie.sh
. ./install-screensaver.sh
. ./install-bind.sh
. ./install-lsof.sh
. ./install-vlc.sh
. ./install-vorbis-tools.sh
. ./install-satty.sh
. ./install-bitwarden.sh
. ./install-phpstorm.sh
. ./install-dev-laravel.sh
. ./install-php-pie.sh
. ./install-php-extensions.sh
. ./install-yarn.sh
. ./install-nextcloud.sh
. ./install-glab.sh
. ./install-whatsapp.sh
. ./install-telegram.sh
. ./install-teams.sh
. ./install-outlook.sh
. ./install-slack.sh
. ./install-yaak.sh
. ./install-opendeck.sh
. ./install-chrome-profiles.sh
. ./install-le-ca.sh
. ./install-openvpn.sh
. ./install-strongswan.sh
. ./install-vpn.sh
. ./install-hyprland-overrides.sh
. ./install-claude-waybar.sh
. ./install-waybar-config.sh
. ./install-mako-config.sh
. ./enable-sshd.sh

# Only turn it back off if this script turned it on. If it was already on, it is
# not ours to switch off -- and its timer will see to it either way.
#
# Torn down here rather than by calling omarchy-sudo-passwordless again, because
# that asks for a password on the way out: its disable path runs `sudo rm` on the
# NOPASSWD file and then `sudo systemctl stop` on the timer, and by then it has
# deleted the very rule that second sudo needed. So both steps go in one sudo
# call, with the rule removed last, and `sudo -n` guarantees that a tear-down
# which cannot be done silently reports itself instead of blocking on a prompt.
if [ "$SUDO_NOPASSWD_WAS_ENABLED" = false ]; then
    if sudo -n test -f "$SUDO_NOPASSWD_FILE" 2>/dev/null; then
        echo "Turning passwordless sudo back off"
        sudo -n bash -c "systemctl stop 'omarchy-nopasswd-expire-$USER.timer' 2>/dev/null
                         rm -f '$SUDO_NOPASSWD_FILE'" ||
            echo "Could not remove $SUDO_NOPASSWD_FILE, leaving it to its expiry timer"
    else
        echo "Passwordless sudo already expired on its own, nothing to turn off"
    fi
fi
