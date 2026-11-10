#!/bin/bash

set -e

# vainfo is the only way to see which VA-API driver actually resolved and which
# codecs it offers. The Intel driver itself is Omarchy's job: its Intel hardware
# step installs intel-media-driver wherever an Intel GPU is present.
echo "Installing VA-API tools"
omarchy-pkg-add libva-utils

echo "Video acceleration setup complete!"
