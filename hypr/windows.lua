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

-- PhpStorm dialogs that open tiled when they should be floating.
for _, title in ipairs({
  "^(Local History).*",
  "^(Welcome to PhpStorm).*",
  "^(Open File).*",
}) do
  o.window({ title = title }, { float = true, persistent_size = true })
end

-- Same, but the mouse is allowed to move focus away from them.
for _, title in ipairs({
  "^(Select Folder).*",
  "^(Yaak Settings).*",
  "^(Slack - Huddle Preview).*",
}) do
  o.window({ title = title }, { float = true, persistent_size = true, stay_focused = false })
end
