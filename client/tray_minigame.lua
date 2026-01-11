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

---@param stationConfig table|nil Optional static configuration {trayCoords, standPos}
function StartTrayBuilding(stationConfig)
    if currentSession and currentSession.active then return end

    local ped = cache.ped
    local coords, trayHeading, zHeight
    local camPos

    if stationConfig then
        -- Static Mode
        -- Teleport player to stand position (Simple set coords for now, better implies task sequence but this works for minigame lock)
        local stand = stationConfig.standPos
        SetEntityCoords(ped, stand.x, stand.y, stand.z, false, false, false, false)
        SetEntityHeading(ped, stand.w)

        local tray = stationConfig.trayCoords
        coords = vector3(tray.x, tray.y, tray.z)
        trayHeading = tray.w
        zHeight = tray.z

        -- Calculate camera relative to Tray (looking down at it)
        -- We place camera in front of the tray (relative to player side) looking down
        -- Assuming player is "behind" tray (typical counter setup)
        local fwd = vector3(math.sin(-math.rad(trayHeading)), math.cos(-math.rad(trayHeading)), 0)
        camPos = coords - (fwd * 0.5) + vector3(0, 0, 1.5)
    else
        -- Dynamic Mode
        local forward = GetEntityForwardVector(ped)
        coords = GetEntityCoords(ped) + (forward * 0.8)
        trayHeading = GetEntityHeading(ped)
        zHeight = coords.z

        camPos = coords - (forward * 0.8) + vector3(0, 0, 1.8)
    end

    -- Capture initial state and clear hand
    local initialState = LocalPlayer.state.waiterTray
    TriggerServerEvent('waiter:server:modifyTray', 'set', {})

    -- Spawn the Tray Prop
    currentTray = Tray.New(sharedConfig.Tray.prop, coords, trayHeading)

    -- Adjust Z to separate tray from ground (only for dynamic, static should be precise)
    if not stationConfig then
        zHeight = zHeight + 0.05
    end

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
            -- Filter export data for items physically on the tray
            local trayData = currentTray:GetExportData(items)

            -- Sync final state to server
            TriggerServerEvent('waiter:server:modifyTray', 'set', trayData)
        end
        cleanupTray(false) -- Destroy local instances, wait for Statebag
    end

    local function onCancel()
        cleanupTray(false)
    end

    -- Create Session
    currentSession = DragDrop.NewSession({
        cameraPos = camPos,
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
                -- Calculate world position
                local worldPos = GetOffsetFromEntityInWorldCoords(currentTray.entity, itemData.x, itemData.y, itemData.z)

                -- Calculate target rotation
                local trayRot = GetEntityRotation(currentTray.entity, 2)
                local targetRot = vector3(trayRot.x + itemData.rx, trayRot.y + itemData.ry, trayRot.z + itemData.rz)

                local newItemEntity = currentSession:SpawnItem(joaat(action.prop), worldPos, key, action.physicsProxy,
                    targetRot)

                if DoesEntityExist(newItemEntity) then
                    SetEntityVelocity(newItemEntity, 0, 0, 0)
                end
            end
        end
    end

    -- Add Dispensers
    local defaultOffsets = {
        burger = { -0.5, 0.2 },
        fries = { -0.5, -0.2 },
        drink = { 0.5, 0.2 },
        coffee = { 0.5, -0.2 }
    }

    for key, action in pairs(sharedConfig.Actions) do
        if action.type == 'food' and action.prop then
            local pos = nil

            -- Priority: Station Config
            if stationConfig and stationConfig.dispensers and stationConfig.dispensers[key] then
                pos = stationConfig.dispensers[key]
            elseif defaultOffsets[key] then
                -- Fallback: Default relative offsets
                local def = defaultOffsets[key]
                pos = getOffset(coords, trayHeading, def[1], def[2])
            end

            if pos then
                currentSession:AddDispenser(action.prop, key, pos, action.physicsProxy)
            end
        end
    end

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
