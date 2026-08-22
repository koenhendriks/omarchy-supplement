-- https://wiki.hypr.land/Configuring/Basics/Variables/#input

hl.config({
  input = {
    -- Focus follows the mouse, but the mouse never takes focus off a window
    -- that was focused by keyboard until it enters a different window.
    follow_mouse = 2,

    -- Drop Omarchy's "compose:caps,shift:both_capslock_cancel" and keep a plain
    -- Caps Lock.
    kb_options = "",
  },
})

-- Three- or four-finger horizontal swipe switches workspaces, 1:1 with the
-- fingers. See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Gestures/
--
-- Both counts are registered rather than one, because the habit differs by
-- machine and by muscle memory: three fingers is what every other desktop uses
-- for this, four is what this config started with. Hyprland only warns about
-- one gesture shadowing another when they share a finger count, so the two
-- coexist.
--
-- Registering three fingers does spend the slot that `drag_3fg` and the
-- focus-movement gestures in Omarchy's stock input.lua would want. Nothing here
-- enables either, so there is no conflict today -- but adding one later means
-- picking a different count for it, not stacking it on three.
--
-- Omarchy binds no gestures of its own (its stock input.lua ships only a
-- commented-out three-finger example), so there is nothing to unset first.
--
-- Only the XPS has a trackpad, so unlike monitors.lua this needs no per-machine
-- branch: on the desktop no swipe events ever arrive and the gestures are inert.
--
-- "horizontal" covers both directions. Two Hyprland defaults shape how it
-- feels, both still at their stock values:
--   gestures:workspace_swipe_invert     (true)  which way the workspaces move
--   gestures:workspace_swipe_create_new (true)  swiping past the last workspace
--                                               opens a new one
for _, fingers in ipairs({ 3, 4 }) do
  hl.gesture({ fingers = fingers, direction = "horizontal", action = "workspace" })
end
