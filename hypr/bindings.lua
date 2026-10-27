-- Personal keybinding overrides, loaded after Omarchy's defaults.
-- See the current set with: omarchy menu keybindings --print
--
-- Any key Omarchy already binds has to be released with hl.unbind() first,
-- otherwise both dispatchers fire.

-- The custom_center layout from custom-layout.lua: promote windows into the
-- centre masters, and split the centre in two.
--
-- o.bind takes the description second -- o.bind(keys, description, dispatcher) --
-- so passing a dispatcher as the second argument leaves the real one nil and
-- Hyprland rejects the bind with "hl.bind: dispatcher must be a dispatcher".
-- The description is not decoration either: it is what
-- `omarchy menu keybindings --print` and SUPER + K list.
--
-- SUPER + RETURN promotes the focused window to master instead of opening a
-- terminal (Omarchy's default), so the terminal moves to CTRL + ALT + T.
hl.unbind("SUPER + RETURN")
o.bind("SUPER + RETURN", "Swap with master", hl.dsp.layout("swapwithmaster"))
o.bind("SUPER + backslash", "Swap with second master", hl.dsp.layout("swapwithmaster2"))
o.bind("SUPER + I", "Add master", hl.dsp.layout("addmaster"))
o.bind("SUPER + D", "Remove master", hl.dsp.layout("removemaster"))
o.bind("CTRL + ALT + T", "Terminal", { omarchy = "terminal" })

-- Omarchy's own screenshot flow (the PRINT key) on a Mac-style shortcut.
o.bind("ALT + SHIFT + 4", "Screenshot", "omarchy-capture-screenshot")

-- File manager on SUPER + E (Omarchy's own is SUPER + SHIFT + F).
o.bind("SUPER + E", "File manager", { launch = "nautilus --new-window" })

-- Close windows with SUPER + Q rather than Omarchy's SUPER + W.
hl.unbind("SUPER + W")
o.bind("SUPER + Q", "Close window", hl.dsp.window.close())

-- Lock on SUPER + L. Quattro moved lock to SUPER + CTRL + L and gave SUPER + L
-- to the workspace layout toggle, which this takes back.
hl.unbind("SUPER + L")
o.bind("SUPER + L", "Lock system", "omarchy-system-lock")

-- Audible feedback on volume changes. Rebinding the keys means repeating the
-- default's { locked, repeating } options, or volume stops working on the lock
-- screen and stops repeating when the key is held.
local volume_feedback = " && ogg123 -q ~/.local/share/omarchy-supplement-resources/audio-volume-change.oga"

hl.unbind("XF86AudioRaiseVolume")
o.bind(
  "XF86AudioRaiseVolume",
  "Volume up",
  "omarchy-audio-output-volume raise" .. volume_feedback,
  { locked = true, repeating = true }
)

hl.unbind("XF86AudioLowerVolume")
o.bind(
  "XF86AudioLowerVolume",
  "Volume down",
  "omarchy-audio-output-volume lower" .. volume_feedback,
  { locked = true, repeating = true }
)



