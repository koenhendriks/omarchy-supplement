-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
-- List current monitors and supported resolutions with: hyprctl monitors all

-- Master layout, tuned for the ultrawide.
hl.config({
  master = {
    -- Make the new window a slave, not the master.
    new_status = "slave",

    -- Put the master window in the dead center.
    orientation = "center",

    -- 0 = ALWAYS center the master window, regardless of window count.
    slave_count_for_center_master = 0,

    -- Master takes exactly 50% (2/4) of the ultrawide.
    mfact = 0.50,
  },
})

-- The Dell monitor (top, centered above the ultrawide).
hl.monitor({ output = "HDMI-A-1", mode = "2560x1440@59.95", position = "1280x0", scale = 1 })

-- The AOC ultrawide (primary, bottom).
hl.monitor({ output = "DP-1", mode = "5120x1440@120.00", position = "0x1440", scale = 1 })

-- --- Workspace binding + per-monitor layout ---
-- Hyprland has no per-monitor layout setting, only per-workspace. So each
-- monitor gets a fixed range of workspaces, and every workspace in that range
-- pins the layout we want for that screen.
--
--   AOC ultrawide (DP-1, bottom)  -> workspaces 1-5,  master
--   Dell P2418D   (HDMI-A-1, top) -> workspaces 6-10, dwindle
local function pin_workspaces(monitor, layout, first, last)
  for workspace = first, last do
    hl.workspace_rule({
      workspace = tostring(workspace),
      monitor = monitor,
      layout = layout,

      -- The first workspace of each range is the one that monitor opens on at
      -- startup. `or nil` keeps the key off the other rules entirely.
      default = workspace == first or nil,
    })
  end
end

pin_workspaces("DP-1", "master", 1, 5)
pin_workspaces("HDMI-A-1", "dwindle", 6, 10)
