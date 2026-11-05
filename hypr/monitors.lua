-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
-- List current monitors and supported resolutions with: hyprctl monitors all

-- --- Which machine is this? ---
-- This repo is installed on two machines with different screens: a desktop with
-- an AOC ultrawide and a Dell above it, and an XPS 15 that has its internal
-- panel alone when undocked and two Dell U2715H over the dock when docked. The
-- layouts differ, and a workspace rule's layout applies whether or not the
-- monitor the rule names is attached -- so "workspaces 1-5 are custom_center on
-- DP-1" also lands on the XPS's panel, which has no DP-1 and no use for a
-- centre-master layout. Hence a branch rather than one shared set of rules.
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

-- --- Spotting the dock ---
-- The dock's two screens arrive over DisplayPort MST, and MST connector names
-- are allocated as the topology is walked rather than fixed to a physical port.
-- They are not stable even within one boot: a login with both Dells attached
-- enumerated DP-3 and DP-6, dropped DP-6, and came back with DP-7 and DP-10.
-- So the dock is detected by counting connected DP outputs rather than by
-- naming one, and the monitors below are matched on the EDID string (`desc:`)
-- rather than on a connector that will be called something else tomorrow.
--
-- This only has to tell "docked" from "XPS on its own": it is called inside the
-- eDP-1 branch, so the desktop's DP-1 ultrawide never reaches it.
local function dp_outputs_connected()
  local connected = 0

  for card = 0, 9 do
    for port = 1, 16 do
      local status = io.open(("/sys/class/drm/card%d-DP-%d/status"):format(card, port), "r")

      if status then
        if status:read("l") == "connected" then
          connected = connected + 1
        end
        status:close()
      end
    end
  end

  return connected
end

-- The two Dells are the same make, model and resolution, so the serial in the
-- EDID is the only thing telling them apart. Swap these two constants if the
-- screens come out the wrong way round -- nothing else needs to change.
local DELL_LEFT = "desc:Dell Inc. DELL U2715H GH85D7B51B6S"
local DELL_RIGHT = "desc:Dell Inc. DELL U2715H GH85D7AH0WYS"

-- --- Workspace binding + per-monitor layout ---
-- Hyprland has no per-monitor layout setting, only per-workspace. So each
-- monitor gets a fixed range of workspaces, and every workspace in that range
-- pins the layout we want for that screen.
--
-- The ranges must also add up to 1-10 and no further. Only SUPER+1..0 are
-- bound, so a monitor handed workspace 11 has no key that reaches it -- which
-- is what happened when all ten were pinned to eDP-1 and the docked Dells were
-- pushed onto 11 and 13.
--
--   XPS 15 (eDP-1, only screen)   -> workspaces 1-10, dwindle
--   XPS 15 docked (eDP-1, left)   -> workspaces 1-2,  dwindle
--     Dell U2715H (middle)        -> workspaces 3-6,  dwindle
--     Dell U2715H (right)         -> workspaces 7-10, dwindle
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

  if dp_outputs_connected() >= 2 then
    -- Docked: the panel keeps the far left, the Dells run off to the right.
    hl.monitor({ output = DELL_LEFT, mode = "2560x1440@59.95", position = "1920x0", scale = 1 })
    hl.monitor({ output = DELL_RIGHT, mode = "2560x1440@59.95", position = "4480x0", scale = 1 })

    pin_workspaces("eDP-1", "dwindle", 1, 2)
    pin_workspaces(DELL_LEFT, "dwindle", 3, 6)
    pin_workspaces(DELL_RIGHT, "dwindle", 7, 10)
  else
    -- Stock dwindle everywhere. custom_center is built around the ultrawide's
    -- 5120px -- it hands the middle half to masters and stacks slaves down the
    -- quarters either side, which at 1920px leaves three columns too narrow to
    -- work in. dwindle is also Hyprland's `general:layout` default, so this pins
    -- what would happen anyway; it is spelled out so the file says which layout
    -- each screen is meant to have rather than leaving one to inference.
    pin_workspaces("eDP-1", "dwindle", 1, 10)
  end
else
  -- The Dell monitor (top, centered above the ultrawide).
  hl.monitor({ output = "HDMI-A-1", mode = "2560x1440@59.95", position = "1280x0", scale = 1 })

  -- The AOC ultrawide (primary, bottom).
  hl.monitor({ output = "DP-1", mode = "5120x1440@120.00", position = "0x1440", scale = 1 })

  pin_workspaces("DP-1", "lua:custom_center", 1, 5)
  pin_workspaces("HDMI-A-1", "dwindle", 6, 10)
end
