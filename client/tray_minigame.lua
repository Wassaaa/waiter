local clientConfig = require 'config.client'
local sharedConfig = require 'config.shared'
local DragDrop = require 'client.lib.dragdrop'

local currentSession = nil
local trayProp = nil

-- Helper to calculate offset coordinate based on heading
local function getOffset(center, heading, dx, dy)
    local rad = math.rad(heading)
    local cos = math.cos(rad)
    local sin = math.sin(rad)
    -- Rotate offsets
    local wx = dx * cos - dy * sin
    local wy = dx * sin + dy * cos
    return vector3(center.x + wx, center.y + wy, center.z)
end

function StartTrayBuilding()
    if currentSession and currentSession.active then return end

    local ped = cache.ped
    local forward = GetEntityForwardVector(ped)
    local coords = GetEntityCoords(ped) + (forward * 0.8)

    -- Level surface height (approx waist height relative to ground, but we use coords.z for simplicity)
    local zHeight = coords.z

    -- Spawn the Tray Prop
    local trayHash = joaat(sharedConfig.Tray.prop)
    lib.requestModel(trayHash)
    trayProp = CreateObject(trayHash, coords.x, coords.y, zHeight, false, false, false)
    FreezeEntityPosition(trayProp, true)
    local trayHeading = GetEntityHeading(ped)
    SetEntityHeading(trayProp, trayHeading)

    -- Define callbacks
    local function cleanupTray()
        if DoesEntityExist(trayProp) then DeleteEntity(trayProp) end
        trayProp = nil
        currentSession = nil
        lib.hideTextUI()
    end

    local function onFinish(itemKeys, items)
        -- Validate items are actually on the tray
        local finalItems = {}
        local trayPos = GetEntityCoords(trayProp)
        local TRAY_RADIUS = 0.25

        for _, item in ipairs(items) do
            if DoesEntityExist(item.entity) then
                local dist = #(GetEntityCoords(item.entity) - trayPos)
                if dist < TRAY_RADIUS then
                    table.insert(finalItems, item.key)
                end
            end
        end

        TriggerServerEvent('waiter:server:modifyTray', 'set', finalItems)
        cleanupTray()
    end

    local function onCancel()
        cleanupTray()
    end

    -- Create Session
    currentSession = DragDrop.NewSession({
        cameraPos = coords - (forward * 0.8) + vector3(0, 0, 1.8),
        lookAt = coords,
        zHeight = zHeight,
        onFinish = onFinish,
        onCancel = onCancel,
        enableCollision = true,
        dispenserCooldown = 1500,
        dispenserRespawnDist = 0.1
    })

    -- Add Dispensers
    -- Left Side
    currentSession:AddDispenser(sharedConfig.Actions.burger.prop, 'burger', getOffset(coords, trayHeading, -0.5, 0.2),
        sharedConfig.Actions.burger.physicsProxy)
    currentSession:AddDispenser(sharedConfig.Actions.fries.prop, 'fries', getOffset(coords, trayHeading, -0.5, -0.2),
        sharedConfig.Actions.fries.physicsProxy)

    -- Right Side
    currentSession:AddDispenser(sharedConfig.Actions.drink.prop, 'drink', getOffset(coords, trayHeading, 0.5, 0.2),
        sharedConfig.Actions.drink.physicsProxy)
    currentSession:AddDispenser(sharedConfig.Actions.coffee.prop, 'coffee', getOffset(coords, trayHeading, 0.5, -0.2),
        sharedConfig.Actions.coffee.physicsProxy)

    -- Start
    lib.showTextUI(
        '[Left Click] Drag Items  \n' ..
        '[Scroll] Adjust Height  \n' ..
        '[Right Click] Remove Item  \n' ..
        '[G] Camera  \n' ..
        '[H] Debug  \n' ..
        '[Space] Finish  \n' ..
        '[ESC] Cancel'
    )
    currentSession:Start()
end

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        if currentSession then
            currentSession:Stop()
        end
        if trayProp and DoesEntityExist(trayProp) then
            DeleteEntity(trayProp)
        end
        lib.hideTextUI()
    end
end)
