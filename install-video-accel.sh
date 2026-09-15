#!/bin/bash

set -e

# intel-media-driver is what hypr/graphics.lua's LIBVA_DRIVER_NAME=iHD resolves
# to, and that override only fires on a machine whose displays all hang off an
# Intel GPU. The desktop has no Intel graphics at all, so installing it there
# would leave a driver nothing can ever load.
#
# Matches Omarchy's own detectors: read the cached sysfs IDs rather than lspci,
# which reads PCI config space and resumes a runtime-suspended GPU.
intel_gpu_present() {
    local device

    for device in /sys/bus/pci/devices/*/; do
        [ "$(cat "$device/vendor" 2>/dev/null)" = 0x8086 ] || continue

        case "$(cat "$device/class" 2>/dev/null)" in
            0x03*) return 0 ;;
        esac
    done

    return 1
}

# vainfo is the only way to see which VA-API driver actually resolved and which
# codecs it offers, so it earns its place on every machine.
echo "Installing VA-API tools"
yay -S --noconfirm --needed libva-utils

if intel_gpu_present; then
    echo "Intel GPU present, installing its VA-API driver"
    yay -S --noconfirm --needed intel-media-driver
else
    echo "No Intel GPU, skipping intel-media-driver"
fi

echo "Video acceleration setup complete!"
