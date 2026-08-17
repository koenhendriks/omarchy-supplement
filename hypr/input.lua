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
