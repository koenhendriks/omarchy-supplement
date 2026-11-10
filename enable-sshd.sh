#!/bin/bash

set -e

# The GitHub account whose public keys are authorized for SSH logins.
GITHUB_KEYS_USER="koenhendriks"

# Omarchy's own setup installs openssh, generates host keys, enables sshd, rate
# limits port 22 in UFW and authorizes the keys. Passing --gh-keys keeps it
# unattended. Once a key is in, it also turns password logins off, so SSH here
# is key-only.
echo "Setting up sshd with the SSH keys of GitHub user $GITHUB_KEYS_USER"
omarchy setup security sshd --gh-keys "$GITHUB_KEYS_USER"

echo "sshd setup complete!"
