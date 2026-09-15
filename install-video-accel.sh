#!/bin/bash

set -e

# hypr/graphics.lua points LIBVA_DRIVER_NAME at the Intel iGPU that drives the
# panel, which needs iHD_drv_video.so to be there or libva fails to load a driver
# at all. libva-utils is what makes the result checkable: `vainfo` is the only
# way to see which driver resolved and which codecs it offers.
echo "Installing Intel VA-API driver and tools"
yay -S --noconfirm --needed intel-media-driver libva-utils

echo "Video acceleration setup complete!"
