local clientConfig = require 'config.client'
local sharedConfig = require 'config.shared'
local DragDrop = require 'client.lib.dragdrop'
local Tray = require 'client.lib.tray'

local currentSession = nil
local currentTray = nil

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

    -- 1. Capture Current State & Clear Hand
    local initialState = LocalPlayer.state.waiterTray
    TriggerServerEvent('waiter:server:modifyTray', 'set', {})

    -- Spawn the Tray Prop
    local trayHeading = GetEntityHeading(ped)
    currentTray = Tray.New(sharedConfig.Tray.prop, coords, trayHeading)

    -- Adjust Z to sit on top of tray surface (Approx 5cm thickness)
    zHeight = zHeight + 0.05

    -- Define callbacks
    local function cleanupTray(preserveItems)
        if currentSession then
            currentSession:Stop(preserveItems)
            currentSession = nil
        end

        -- Delete tray ONLY if it's not attached to the player (Cancelled/Failed)
        -- If preserved, we assume tray is carried.
        if currentTray and DoesEntityExist(currentTray.entity) and not IsEntityAttached(currentTray.entity) then
            DeleteEntity(currentTray.entity)
        end

        currentTray = nil
        lib.hideTextUI()
    end

    local function onFinish(itemKeys, items)
        if currentTray and DoesEntityExist(currentTray.entity) then
            -- Use the Tray class to filter and calculate export data
            local trayData = currentTray:GetExportData(items)

            -- Sync to Server (which updates Statebag -> updates Visuals for all)
            TriggerServerEvent('waiter:server:modifyTray', 'set', trayData)
        end
        cleanupTray(false) -- Destroy local instances, wait for Statebag
    end

    local function onCancel()
        cleanupTray(false)
    end

    -- Create Session
    currentSession = DragDrop.NewSession({
        cameraPos = coords - (forward * 0.8) + vector3(0, 0, 1.8),
        lookAt = coords,
        zHeight = zHeight,
        onFinish = onFinish,
        onCancel = onCancel,
        onDebug = function()
            if currentTray then currentTray:DrawDebugZone() end
        end,
        enableCollision = true,
        dispenserCooldown = 1500,
        dispenserRespawnDist = 0.1
    })

    -- 2. Pre-load Items from State
    if initialState and type(initialState) == 'table' then
        for _, itemData in ipairs(initialState) do
            local key = itemData.key
            local action = sharedConfig.Actions[key]

            if action and action.prop and currentTray and DoesEntityExist(currentTray.entity) then
                -- Calculate World Position
                local worldPos = GetOffsetFromEntityInWorldCoords(currentTray.entity, itemData.x, itemData.y, itemData.z)

                -- Spawn Item using Session Logic (registers it for physics)
                -- Calculate Target Rotation (World = Tray + Relative)
                local trayRot = GetEntityRotation(currentTray.entity, 2)
                local targetRot = vector3(trayRot.x + itemData.rx, trayRot.y + itemData.ry, trayRot.z + itemData.rz)

                local newItemEntity = currentSession:SpawnItem(joaat(action.prop), worldPos, key, action.physicsProxy,
                    targetRot)

                if DoesEntityExist(newItemEntity) then
                    -- Ensure it wakes up with correct velocity (zero)
                    SetEntityVelocity(newItemEntity, 0, 0, 0)
                end
            end
        end
    end

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
        if currentTray and DoesEntityExist(currentTray.entity) then
            DeleteEntity(currentTray.entity)
        end
        lib.hideTextUI()
    end
end)
