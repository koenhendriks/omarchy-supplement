-- A centre-master layout for the ultrawide: masters occupy the middle half of
-- the screen and can be split between several windows, with slaves stacked down
-- the left and right quarters.
--
-- Registered as "custom_center" and selected per workspace in monitors.lua.
-- Driven by the layoutmsg binds in bindings.lua: addmaster, removemaster,
-- swapwithmaster and swapwithmaster2 all arrive through layout_msg below.
-- One state table per workspace, never one shared table.
--
-- recalculate() runs for every workspace using this layout, not just the visible
-- one, and it drops from window_order any address it does not see in ctx.targets.
-- Shared state therefore means laying out workspace 1 deletes workspace 2's whole
-- order, and the next recalculate for workspace 2 rebuilds it from ctx.targets --
-- silently discarding whatever was promoted with swapwithmaster. One notification
-- is enough to trigger that round trip, so a window would jump into master with
-- nobody touching the keyboard.
--
-- Keying by workspace also stops `masters` leaking: splitting the centre on one
-- workspace used to split it on all of them.
local states = {}

local function state_for(ctx)
    local key

    for _, target in ipairs(ctx.targets) do
        if target.window and target.window.workspace then
            key = target.window.workspace.id or target.window.workspace.name
            break
        end
    end

    -- layout_msg can arrive with nothing tiled yet; fall back to whatever has focus.
    if not key then
        local active = hl.get_active_window()
        if active and active.workspace then
            key = active.workspace.id or active.workspace.name
        end
    end

    key = key or "unknown"

    if not states[key] then
        states[key] = {
            masters = 1,
            swap_address = nil,
            swap_master_idx = 1, -- Which master slot to swap into (1 = left, 2 = right, ...)
            window_order = {}
        }
    end

    return states[key]
end

hl.layout.register("custom_center", {
    recalculate = function(ctx)
        local layout_state = state_for(ctx)
        local n = #ctx.targets
        if n == 0 then return end
        
        -- 1. Sync Hyprland's internal windows with our persistent order
        local current_addresses = {}
        local target_map = {}
        local non_window_targets = {}

        for _, target in ipairs(ctx.targets) do
            if target.window then
                local addr = target.window.address
                current_addresses[addr] = true
                target_map[addr] = target
            else
                table.insert(non_window_targets, target)
            end
        end

        for i = #layout_state.window_order, 1, -1 do
            if not current_addresses[layout_state.window_order[i]] then
                table.remove(layout_state.window_order, i)
            end
        end

        local order_set = {}
        for _, addr in ipairs(layout_state.window_order) do
            order_set[addr] = true
        end
        
        for _, target in ipairs(ctx.targets) do
            if target.window and not order_set[target.window.address] then
                table.insert(layout_state.window_order, target.window.address)
            end
        end

        -- 2. Execute Swap Logic
        if layout_state.swap_address then
            local target_idx = nil
            for i, addr in ipairs(layout_state.window_order) do
                if addr == layout_state.swap_address then
                    target_idx = i
                    break
                end
            end

            -- Grab the requested master index
            local m_idx = layout_state.swap_master_idx

            -- Swap ONLY IF:
            -- 1. The target window exists
            -- 2. It isn't already sitting in the requested master slot
            -- 3. We actually have enough windows on screen to fill that slot
            -- 4. The user has actively split the masters enough to allow it
            if target_idx and target_idx ~= m_idx and #layout_state.window_order >= m_idx and layout_state.masters >= m_idx then
                local temp = layout_state.window_order[m_idx]
                layout_state.window_order[m_idx] = layout_state.window_order[target_idx]
                layout_state.window_order[target_idx] = temp
            end
            
            -- Clear the triggers so it doesn't loop continuously
            layout_state.swap_address = nil
            layout_state.swap_master_idx = 1
        end
        
        -- 3. Build the final rendering array based on our persistent order
        local render_targets = {}
        for _, addr in ipairs(layout_state.window_order) do
            if target_map[addr] then
                table.insert(render_targets, target_map[addr])
            end
        end
        
        for _, t in ipairs(non_window_targets) do
            table.insert(render_targets, t)
        end

        -- 4. Calculate Layout Math
        local total_render = #render_targets
        if total_render == 0 then return end

        local m_count = math.min(layout_state.masters, total_render)
        local s_count = total_render - m_count
        
        local l_count = math.ceil(s_count / 2)
        local r_count = math.floor(s_count / 2)
        
        local area = ctx.area
        local w_quarter = area.w / 4
        
        local master_w = (area.w / 2) / math.max(1, m_count)
        local x_master = area.x + w_quarter
        
        local current_i = 1
        
        -- Place Masters
        for i = 1, m_count do
            if render_targets[current_i] then
                render_targets[current_i]:place({
                    x = x_master + (i - 1) * master_w,
                    y = area.y,
                    w = master_w,
                    h = area.h
                })
                current_i = current_i + 1
            end
        end
        
        -- Place Left Slaves
        if l_count > 0 then
            local slave_h = area.h / l_count
            for i = 1, l_count do
                if render_targets[current_i] then
                    render_targets[current_i]:place({
                        x = area.x,
                        y = area.y + (i - 1) * slave_h,
                        w = w_quarter,
                        h = slave_h
                    })
                    current_i = current_i + 1
                end
            end
        end
        
        -- Place Right Slaves
        if r_count > 0 then
            local slave_h = area.h / r_count
            for i = 1, r_count do
                if render_targets[current_i] then
                    render_targets[current_i]:place({
                        x = area.x + area.w - w_quarter,
                        y = area.y + (i - 1) * slave_h,
                        w = w_quarter,
                        h = slave_h
                    })
                    current_i = current_i + 1
                end
            end
        end
    end,
    
    -- Intercept layout commands dispatched by your keybinds
    layout_msg = function(ctx, msg)
        local layout_state = state_for(ctx)
        local command = msg:match("^(%S+)")
        
        if command == "addmaster" then
            layout_state.masters = layout_state.masters + 1
            
            -- Automatically pull the focused window into the newly created slot
            local active = hl.get_active_window()
            if active then
                layout_state.swap_address = active.address
                layout_state.swap_master_idx = layout_state.masters
            end
            
        elseif command == "removemaster" then
            layout_state.masters = math.max(1, layout_state.masters - 1)
            
        elseif command == "swapwithmaster" then
            local active = hl.get_active_window()
            if active then
                layout_state.swap_address = active.address
                layout_state.swap_master_idx = 1 -- Target the Left Master
            end
            
        elseif command == "swapwithmaster2" then
            local active = hl.get_active_window()
            if active then
                -- Automatically split the center into 2 if it isn't already
                if layout_state.masters < 2 then
                    layout_state.masters = 2
                end
                
                layout_state.swap_address = active.address
                layout_state.swap_master_idx = 2 -- Target the Right Master
            end
        end
    end
})