#!/bin/bash

set -e

omarchy-pkg-add cronie
sudo systemctl enable --now cronie.service



