local config = require 'config.shared'

ServerTray = {}

---@param src number Player source
---@param item string Item name
function ServerTray.Add(src, item)
    local tray = Player(src).state.waiterTray or {}

    if type(item) ~= 'string' then return end

    local actionData = config.Items[item]
    if not actionData or actionData.type ~= 'food' then
        return exports.qbx_core:Notify(src, 'Invalid item', 'error')
    end

    if #tray >= config.MaxHandItems then
        return exports.qbx_core:Notify(src, 'Tray is full!', 'error')
    end

    table.insert(tray, item)
    Player(src).state:set('waiterTray', tray, true)
    exports.qbx_core:Notify(src, ('Added %s'):format(actionData.label), 'success')
end

---@param src number Player source
---@param item string|table Item name or complex data
function ServerTray.Remove(src, item)
    local tray = Player(src).state.waiterTray or {}
    if not item then return end

    local removed = false
    for i, val in ipairs(tray) do
        -- Check for complex match or simple match
        local match = false
        if type(val) == 'table' and type(item) == 'table' then
            if val.key == item.key and val.x == item.x and val.y == item.y and val.z == item.z then
                match = true
            end
        elseif val == item then
            match = true
        end

        if match then
            table.remove(tray, i)
            local key = type(val) == 'table' and val.key or val
            local actionData = config.Items[key]
            exports.qbx_core:Notify(src, ('Removed %s'):format(actionData and actionData.label or key), 'info')
            removed = true
            break
        end
    end

    if removed then
        Player(src).state:set('waiterTray', tray, true)
    end
end

---@param src number Player source
function ServerTray.Clear(src)
    Player(src).state:set('waiterTray', {}, true)
    exports.qbx_core:Notify(src, 'Tray cleared', 'info')
end

---@param src number Player source
---@param trayData table List of complex items
function ServerTray.Set(src, trayData)
    if type(trayData) ~= 'table' then return end

    -- Validate complex items
    local validatedTray = {}
    for _, data in ipairs(trayData) do
        local key = data.key
        if key and config.Items[key] then
            -- Sanitize
            table.insert(validatedTray, {
                key = key,
                x = tonumber(data.x),
                y = tonumber(data.y),
                z = tonumber(data.z),
                rx = tonumber(data.rx),
                ry = tonumber(data.ry),
                rz = tonumber(data.rz)
            })
        end
    end

    if #validatedTray > config.MaxHandItems then
        return exports.qbx_core:Notify(src, 'Too many items!', 'error')
    end

    Player(src).state:set('waiterTray', validatedTray, true)
    exports.qbx_core:Notify(src, 'Tray assembled', 'success')
end
