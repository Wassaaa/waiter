local DragDrop = require 'client.lib.dragdrop'
local sharedConfig = require 'config.shared'

---@class StationConfig
---@field standPos vector4 Player standing position (x, y, z, w)
---@field trayCoords vector4 Tray position (x, y, z, w)
---@field trayHash number Model hash

RegisterCommand('waiter:setup', function()
    local ped = cache.ped
    local rawPos = GetEntityCoords(ped)
    local standHeading = GetEntityHeading(ped)

    -- Snap to ground for stand position
    local foundGround, zGround = GetGroundZFor_3dCoord(rawPos.x, rawPos.y, rawPos.z, false)
    local standZ = foundGround and zGround or rawPos.z
    local standPos = vector3(rawPos.x, rawPos.y, standZ)

    local standVec4 = vector4(standPos.x, standPos.y, standPos.z, standHeading)

    -- Calculate initial tray pos in front of player
    local forward = GetEntityForwardVector(ped)
    local trayPos = standPos + (forward * 0.8)
    local trayModel = joaat(sharedConfig.Tray.prop)

    lib.print.info('Station Setup Started')
    lib.print.info('Stand Position captured:', standVec4)

    -- Create Session
    local session = DragDrop.NewSession({
        cameraPos = standPos - (forward * 1.5) + vector3(0, 0, 2.0),
        lookAt = trayPos,
        zHeight = trayPos.z,
        enableCollision = false, -- Ghost mode for placement
        onFinish = function(keys, items)
            local trayItem = nil
            local dispensers = {}

            for _, item in ipairs(items) do
                if item.key == 'setup_tray' then
                    trayItem = item
                elseif string.sub(item.key, 1, 10) == 'dispenser_' then
                    local actionKey = string.sub(item.key, 11)
                    if DoesEntityExist(item.entity) then
                        local pos = GetEntityCoords(item.entity)
                        local heading = GetEntityHeading(item.entity)
                        dispensers[actionKey] = vector4(pos.x, pos.y, pos.z, heading)
                    end
                end
            end

            if trayItem and DoesEntityExist(trayItem.entity) then
                local finalPos = GetEntityCoords(trayItem.entity)
                local finalRot = GetEntityHeading(trayItem.entity)
                local finalVec4 = vector4(finalPos.x, finalPos.y, finalPos.z, finalRot)

                local output = string.format([[
-- Station Config Output
trayCoords = vector4(%.4f, %.4f, %.4f, %.4f),
standPos = vector4(%.4f, %.4f, %.4f, %.4f),
dispensers = {
]],
                    finalVec4.x, finalVec4.y, finalVec4.z, finalVec4.w,
                    standVec4.x, standVec4.y, standVec4.z, standVec4.w)

                for key, vec in pairs(dispensers) do
                    output = output ..
                        string.format("    %s = vector4(%.4f, %.4f, %.4f, %.4f),\n", key, vec.x, vec.y, vec.z, vec.w)
                end
                output = output .. "},"

                print('^2[Waiter Setup] Configuration Generated:^7')
                print(output)
                lib.notify({ type = 'success', description = 'Config printed to F8 console' })
            else
                lib.notify({ type = 'error', description = 'Tray entity missing?' })
            end
        end,
        onCancel = function()
            lib.notify({ type = 'info', description = 'Setup cancelled' })
        end
    })

    -- Spawn Tray
    if lib.requestModel(trayModel) then
        local trayEntity = CreateObject(trayModel, trayPos.x, trayPos.y, trayPos.z, false, false, false)
        SetEntityHeading(trayEntity, standHeading)
        session:AddItem(trayEntity, 'setup_tray', nil)
    end

    -- Spawn Dispensers
    local spawnOffset = 0.5
    for key, data in pairs(sharedConfig.Actions) do
        if data.type == 'food' and data.prop then
            local model = joaat(data.prop)
            if lib.requestModel(model) then
                local dPos = trayPos + vector3(math.random() * 0.5 - 0.25, math.random() * 0.5 - 0.25, 0.2)
                local entity = CreateObject(model, dPos.x, dPos.y, dPos.z, false, false, false)
                session:AddItem(entity, 'dispenser_' .. key, nil)
            end
        end
    end

    session:Start()

    lib.showTextUI(
        '[Left Click] Drag Items  \n' ..
        '[Scroll] Adjust Height  \n' ..
        '[Q/E] Rotate \n' ..
        '[Space] Finish & Print  \n' ..
        '[ESC] Cancel'
    )
end, false)
