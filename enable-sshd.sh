#!/bin/bash

set -e

sudo systemctl enable sshd
sudo systemctl start sshd
sudo ufw allow 22/tcp
