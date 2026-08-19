-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
-- List current monitors and supported resolutions with: hyprctl monitors all

-- --- Which machine is this? ---
-- This repo is installed on two machines with different screens: a desktop with
-- an AOC ultrawide and a Dell above it, and an XPS 15 with only its internal
-- panel. The layouts differ, and a workspace rule's layout applies whether or
-- not the monitor the rule names is attached -- so "workspaces 1-5 are
-- custom_center on DP-1" also lands on the XPS's panel, which has no DP-1 and no
-- use for a centre-master layout. Hence a branch rather than one shared set of
-- rules.
--
-- The connector is read out of /sys/class/drm rather than asked for with
-- hl.get_monitors(). The kernel has filled in connector status before Hyprland
-- is even started, so /sys answers the same during the initial config parse as
-- it does on a later `hyprctl reload`, whereas hl.get_monitors() depends on the
-- backend having enumerated outputs by the time the config is read. Whether it
-- has is untested here -- confirming it either way means restarting Hyprland and
-- losing the session -- so this deliberately sidesteps the question instead of
-- betting on the answer.
local function output_connected(output)
  -- Card numbering is not stable across boots (the XPS panel is card2-eDP-1
  -- today), so try each card instead of hardcoding one.
  for card = 0, 9 do
    local status = io.open(("/sys/class/drm/card%d-%s/status"):format(card, output), "r")

    if status then
      local connected = status:read("l") == "connected"
      status:close()

      if connected then
        return true
      end
    end
  end

  return false
end

-- --- Workspace binding + per-monitor layout ---
-- Hyprland has no per-monitor layout setting, only per-workspace. So each
-- monitor gets a fixed range of workspaces, and every workspace in that range
-- pins the layout we want for that screen.
--
--   XPS 15 (eDP-1, only screen)   -> workspaces 1-10, dwindle
--   AOC ultrawide (DP-1, bottom)  -> workspaces 1-5,  lua:custom_center
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

-- An internal panel means the XPS; the desktop has no eDP output at all.
if output_connected("eDP-1") then
  hl.monitor({ output = "eDP-1", mode = "1920x1200@59.95", position = "0x0", scale = 1 })

  -- Stock dwindle everywhere. custom_center is built around the ultrawide's
  -- 5120px -- it hands the middle half to masters and stacks slaves down the
  -- quarters either side, which at 1920px leaves three columns too narrow to
  -- work in. dwindle is also Hyprland's `general:layout` default, so this pins
  -- what would happen anyway; it is spelled out so the file says which layout
  -- each screen is meant to have rather than leaving one to inference.
  pin_workspaces("eDP-1", "dwindle", 1, 10)
else
  -- The Dell monitor (top, centered above the ultrawide).
  hl.monitor({ output = "HDMI-A-1", mode = "2560x1440@59.95", position = "1280x0", scale = 1 })

  -- The AOC ultrawide (primary, bottom).
  hl.monitor({ output = "DP-1", mode = "5120x1440@120.00", position = "0x1440", scale = 1 })

  pin_workspaces("DP-1", "lua:custom_center", 1, 5)
  pin_workspaces("HDMI-A-1", "dwindle", 6, 10)
end
