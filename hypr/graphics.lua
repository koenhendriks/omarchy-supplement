-- Video acceleration overrides, loaded after Omarchy's defaults.

-- Omarchy's default/hypr/nvidia.lua sets LIBVA_DRIVER_NAME=nvidia for any NVIDIA
-- GPU with GSP firmware (Turing or newer). It only asks whether such a GPU
-- exists, not whether it drives anything. On this hybrid laptop the panel hangs
-- off the Intel iGPU and the RTX 3050 Ti is a bare 3D controller with no outputs,
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
-- boot_vga marks the primary display adapter. Read from sysfs rather than via
-- lspci: lspci reads PCI config space, which resumes a runtime-suspended dGPU,
-- and on a hybrid laptop that wake alone outlasts Hyprland's 1.5s config reload
-- budget. nvidia.lua avoids lspci for the same reason.
local intel_drives_the_display = o.shell_succeeds([[
  for device in /sys/bus/pci/devices/*/; do
    [ "$(cat "$device/boot_vga" 2>/dev/null)" = 1 ] &&
      [ "$(cat "$device/vendor" 2>/dev/null)" = 0x8086 ] &&
      exit 0
  done
  exit 1
]])

-- Guarded on the driver actually being installed: an unresolvable
-- LIBVA_DRIVER_NAME makes libva fail outright instead of falling back, which
-- would cost hardware decode everywhere rather than just here.
local intel_va_driver_installed = o.shell_succeeds("[ -e /usr/lib/dri/iHD_drv_video.so ]")

if intel_drives_the_display and intel_va_driver_installed then
  hl.env("LIBVA_DRIVER_NAME", "iHD")
end
