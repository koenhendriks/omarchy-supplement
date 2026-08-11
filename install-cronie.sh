#!/bin/bash

set -e

yay -S --noconfirm --needed cronie
sudo systemctl enable --now cronie.service



