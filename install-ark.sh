#!/bin/bash

set -e

echo "Installing ark"
# 7zip and unrar are optional deps, and without them ark reports the archive
# itself as unsupported rather than a missing helper -- for the two formats work
# attachments actually arrive in.
omarchy-pkg-add ark 7zip unrar

echo "Ark setup complete!"
