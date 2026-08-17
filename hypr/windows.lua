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

-- zen-cal, opened from the bar: park it top-right, under the clock.
o.window({ title = "^(.*zen-cal.*)$", class = "^(org\\.kde\\.konsole)$" }, {
  float = true,
  workspace = "current silent",
  move = { "(monitor_w-1280-520)", "(monitor_h*0.03)" },
  size = { "(monitor_w*0.1)", "(monitor_h*0.2)" },
})

-- LazyVPN.
o.window("org.lazyvpn", { float = true, center = true, size = { 900, 600 } })
