-- Look'n'feel overrides, loaded after Omarchy's defaults.
--
-- Not to be confused with ~/.config/hypr/looknfeel.lua, which is Omarchy's own
-- (commented-out) template. Both are loaded; this one goes last and wins.

-- Omarchy's default looknfeel.lua ships
-- `hl.animation({ leaf = "workspaces", enabled = false })`, so switching
-- workspaces cuts instantly with nothing to show which way it went. That is
-- fine with a keyboard, where you know what you just pressed, and much less
-- fine with the MX Master's thumb button: the gesture fires on release, so the
-- only feedback that a swipe registered at all -- and in which direction -- is
-- the transition itself. See install-logiops.sh.
--
-- `speed` is a duration in deciseconds, not a rate: higher is slower. 3 (300ms)
-- matches what Omarchy already uses for specialWorkspace, so the two read as
-- the same system. Styles: slide, slidevert, fade, slidefade, slidefadevert.
hl.animation({ leaf = "workspaces", enabled = true, speed = 3, bezier = "easeOutQuint", style = "slide" })
