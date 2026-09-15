-- Video acceleration overrides, loaded after Omarchy's defaults.

-- Omarchy's default/hypr/nvidia.lua sets LIBVA_DRIVER_NAME=nvidia for any NVIDIA
-- GPU with GSP firmware (Turing or newer). It only asks whether such a GPU
-- exists, not whether it drives anything. On the XPS the panel hangs off the
-- Intel iGPU and the RTX 3050 Ti is a bare 3D controller with no outputs at all,
-- so that default sends video decode to the dGPU while Chrome renders, and
-- Hyprland scans out, on Intel.
--
-- Every decoded frame then has to cross GPUs as a dmabuf import, and those
-- imports fail intermittently. The symptoms all point at the player, not at the
-- driver: YouTube flickering, video black while the audio keeps playing, a
-- resize that fixes it for a while by forcing a fresh buffer allocation, and a
-- GPU process that eventually gives up and takes the tab or the app with it
-- (`GPU process isn't usable. Goodbye.`). Pointing VA-API back at the GPU that
-- owns the display keeps decode and composite on the same device.
--
-- This runs on the desktop too, so the test is which GPU has a *connected
-- output*, not which one is boot_vga. boot_vga is whatever the firmware picked
-- as primary at POST, which on a desktop is not reliably the card the monitors
-- are plugged into: a board that leaves the iGPU enabled can hand boot_vga to
-- Intel while a discrete card drives every screen, and forcing iHD there would
-- recreate this very bug in mirror image. Requiring that *no* non-Intel GPU has
-- a connected output also means a machine with screens on both falls through to
-- Omarchy's default rather than this guessing which one matters.
--
-- Read from sysfs rather than via lspci: lspci reads PCI config space, which
-- resumes a runtime-suspended dGPU, and on a hybrid laptop that wake alone
-- outlasts Hyprland's 1.5s config reload budget. nvidia.lua avoids lspci for the
-- same reason.
local intel_alone_drives_the_displays = o.shell_succeeds([[
  intel=0
  other=0

  for status in /sys/class/drm/card*-*/status; do
    [ "$(cat "$status" 2>/dev/null)" = connected ] || continue

    connector=${status%/status}
    card=${connector##*/}
    card=${card%%-*}

    if [ "$(cat "/sys/class/drm/$card/device/vendor" 2>/dev/null)" = 0x8086 ]; then
      intel=1
    else
      other=1
    fi
  done

  [ "$intel" = 1 ] && [ "$other" = 0 ]
]])

-- Guarded on the driver actually being installed: an unresolvable
-- LIBVA_DRIVER_NAME makes libva fail outright instead of falling back, which
-- would cost hardware decode everywhere rather than just here.
local intel_va_driver_installed = o.shell_succeeds("[ -e /usr/lib/dri/iHD_drv_video.so ]")

if intel_alone_drives_the_displays and intel_va_driver_installed then
  hl.env("LIBVA_DRIVER_NAME", "iHD")
end
