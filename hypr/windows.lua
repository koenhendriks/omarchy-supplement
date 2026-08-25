-- See https://wiki.hypr.land/Configuring/Basics/Window-Rules/

-- Apps that should always float, and remember the size they were left at.
for _, class in ipairs({
  "^(org\\.telegram\\.desktop)$",
  "^(nwg-look)$",
  "^(org\\.pulseaudio\\.pavucontrol)$",
  "^(blueman-manager)$",
  "^(whatsapp-electron)$",
  "^(Bitwarden)$",
  "^(org\\.kde\\.dolphin)$",
  "^(org\\.kde\\.ark)$",
  "^(1password)$",
  "^(xdg-desktop-portal-gtk)$",
}) do
  o.window(class, { float = true, persistent_size = true })
end

-- Same, but the mouse is allowed to move focus away from them.
for _, title in ipairs({
  "^(Local History).*",
  "^(Welcome to PhpStorm).*",
  "^(Open File).*",
  "^(Select Folder).*",
  "^(Yaak Settings).*",
  "^(Slack - Huddle Preview).*",
}) do
  o.window({ title = title }, { float = true, persistent_size = true, stay_focused = false })
end

-- JetBrains dialogs (Open Project, Search & Replace, confirmations) are modal,
-- and the JVM re-asserts activation for them whenever focus moves elsewhere.
-- Omarchy sets misc.focus_on_activate globally, so Hyprland honours that and
-- yanks focus straight back: the pointer leaves the dialog, the dialog takes
-- focus again, and the window cannot be left with the mouse at all.
--
-- Scoped to floating windows of the class so only the dialogs stop demanding
-- focus back. The main IDE window keeps activation, so anything that raises
-- PhpStorm from outside still works. Same rule Omarchy uses for Telegram in
-- default/hypr/apps/telegram.lua, and it matches by class + float the way the
-- pre-v4 config tagged these windows.
o.window({ class = "^(jetbrains-.*)$", float = true }, { focus_on_activate = false })
