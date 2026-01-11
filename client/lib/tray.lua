local sharedConfig = require 'config.shared'
local clientConfig = require 'config.client'

---@class Tray
---@field entity number Entity handle
---@field model number Model hash
---@field items table<number, number> Attached item entities
local Tray = {}
Tray.__index = Tray

---Create a new Tray instance on the ground (for minigame etc)
---@param model string|number Prop model
---@param coords vector3 Spawn position
---@param heading number Heading
---@return Tray|nil
function Tray.New(model, coords, heading)
    local self = setmetatable({}, Tray)
    self.items = {}
    -- Fix type casting for lint
    self.model = (type(model) == 'string' and joaat(model) or model) --[[@as number]]

    if lib and lib.requestModel then
        lib.requestModel(self.model)
    else
        RequestModel(self.model)
        while not HasModelLoaded(self.model) do Wait(0) end
    end

    self.entity = CreateObject(self.model, coords.x, coords.y, coords.z, false, false, false)
    lib.print.info('DEBUG: Tray Entity Created:', self.entity, 'at', coords)

    if self.entity == 0 then
        lib.print.error('ERROR: Failed to create Tray object for model', self.model, 'at', coords)
        return nil
    end

    SetEntityHeading(self.entity, heading)
    FreezeEntityPosition(self.entity, true)

    return self
end

---Create a new Tray instance already attached to a ped (for statebag sync)
---@param ped number Ped handle
---@return Tray|nil
function Tray.CreateAttached(ped)
    local self = setmetatable({}, Tray)
    self.items = {}
    self.model = joaat(sharedConfig.Tray.prop)

    if lib and lib.requestModel then
        lib.requestModel(self.model)
    else
        RequestModel(self.model)
        while not HasModelLoaded(self.model) do Wait(0) end
    end

    -- Create object at 0,0,0 initially, then attach using offsets
    self.entity = CreateObject(self.model, 0, 0, 0, false, false, false)

    if self.entity == 0 then
        lib.print.error('ERROR: Failed to create Tray object attached to ped', ped)
        return nil
    end

    SetEntityCollision(self.entity, false, false)

    -- Attach using Shared Config
    local config = sharedConfig.Tray
    local off = config.offset
    local rot = config.rotation

    AttachEntityToEntity(self.entity, ped, GetPedBoneIndex(ped, config.bone),
        off.x, off.y, off.z,
        rot.x, rot.y, rot.z,
        true, true, false, true, 1, true
    )

    return self
end

---Sync items from Statebag data to the tray
---@param stateItems table List of item data {key, x, y, z, rx, ry, rz}
function Tray:AddStateItems(stateItems)
    for _, itemData in ipairs(stateItems) do
        local key = itemData.key
        local action = sharedConfig.Actions[key]
        if action and action.prop then
            local model = joaat(action.prop)
            if lib and lib.requestModel then
                lib.requestModel(model)
            else
                RequestModel(model)
                while not HasModelLoaded(model) do Wait(0) end
            end

            local itemEntity = CreateObject(model, 0, 0, 0, false, false, false)
            SetEntityCollision(itemEntity, false, false)

            AttachEntityToEntity(itemEntity, self.entity, 0,
                itemData.x, itemData.y, itemData.z,
                itemData.rx, itemData.ry, itemData.rz,
                false, false, false, false, 0, true
            )

            table.insert(self.items, itemEntity)
        else
            lib.print.error('DEBUG: Missing action or prop for key', key)
        end
    end
end

---Calculate tray data from a list of candidate items
---Filters items that are not physically on the tray using Bounding Box logic.
---@param candidateItems table List of {entity, key} objects
---@return table trayData List of {key, x, y, z, rx, ry, rz} synced data
function Tray:GetExportData(candidateItems)
    local trayData = {}
    local trayRot = GetEntityRotation(self.entity, 2)

    -- Get Tray Bounding Box
    local tMin, tMax = GetModelDimensions(self.model)
    local minX, maxX = tMin.x, tMax.x
    local minY, maxY = tMin.y, tMax.y
    local minZ, maxZBottom = tMin.z, tMax.z
    local maxZTop = maxZBottom + 0.5

    for _, item in ipairs(candidateItems) do
        if DoesEntityExist(item.entity) then
            local itemEntity = item.entity
            local itemModel = GetEntityModel(itemEntity)

            -- Calculate Item Bottom Center (approximate)
            -- We assume item is relatively upright for this check.
            local iMin, _ = GetModelDimensions(itemModel)
            local itemPos = GetEntityCoords(itemEntity)

            local bottomPos = GetOffsetFromEntityInWorldCoords(itemEntity, 0.0, 0.0, iMin.z)

            -- Transform this point to Tray Local Space
            local localPos = GetOffsetFromEntityGivenWorldCoords(self.entity, bottomPos.x, bottomPos.y, bottomPos.z)

            -- Check if this Local Point is inside the Tray's "Volume"
            local inX = localPos.x >= minX and localPos.x <= maxX
            local inY = localPos.y >= minY and localPos.y <= maxY
            local inZ = localPos.z >= (minZ - 0.1) and localPos.z <= maxZTop -- tolerance on bottom

            if inX and inY and inZ then
                local itemRot = GetEntityRotation(itemEntity, 2)
                local relRot = itemRot - trayRot

                -- We export the ITEM ORIGIN offset, not the bottom offset
                local originOffset = GetOffsetFromEntityGivenWorldCoords(self.entity, itemPos.x, itemPos.y, itemPos.z)

                table.insert(trayData, {
                    key = item.key,
                    x = originOffset.x,
                    y = originOffset.y,
                    z = originOffset.z,
                    rx = relRot.x,
                    ry = relRot.y,
                    rz = relRot.z
                })
            else
                lib.print.info('DEBUG: Item excluded', item.key,
                    string.format('LocalPos: %.2f, %.2f, %.2f | Bounds X[%.2f, %.2f] Y[%.2f, %.2f]',
                        localPos.x, localPos.y, localPos.z, minX, maxX, minY, maxY))
            end
        end
    end

    return trayData
end

---Draw debug visuals for the valid tray zone
function Tray:DrawDebugZone()
    if not DoesEntityExist(self.entity) then return end

    local tMin, tMax = GetModelDimensions(self.model)
    local minZ = tMin.z
    local maxZ = tMax.z + 0.5

    -- Corners in Local Space
    -- Bottom Face (at minZ)
    local c1 = vector3(tMin.x, tMin.y, minZ)
    local c2 = vector3(tMax.x, tMin.y, minZ)
    local c3 = vector3(tMax.x, tMax.y, minZ)
    local c4 = vector3(tMin.x, tMax.y, minZ)

    -- Top Face (at maxZ)
    local c5 = vector3(tMin.x, tMin.y, maxZ)
    local c6 = vector3(tMax.x, tMin.y, maxZ)
    local c7 = vector3(tMax.x, tMax.y, maxZ)
    local c8 = vector3(tMin.x, tMax.y, maxZ)

    local function toWorld(vec)
        return GetOffsetFromEntityInWorldCoords(self.entity, vec.x, vec.y, vec.z)
    end

    local w1, w2, w3, w4 = toWorld(c1), toWorld(c2), toWorld(c3), toWorld(c4)
    local w5, w6, w7, w8 = toWorld(c5), toWorld(c6), toWorld(c7), toWorld(c8)

    -- Draw Lines (Red Box)
    local r, g, b = 255, 0, 0

    -- Bottom Loop
    DrawLine(w1.x, w1.y, w1.z, w2.x, w2.y, w2.z, r, g, b, 255)
    DrawLine(w2.x, w2.y, w2.z, w3.x, w3.y, w3.z, r, g, b, 255)
    DrawLine(w3.x, w3.y, w3.z, w4.x, w4.y, w4.z, r, g, b, 255)
    DrawLine(w4.x, w4.y, w4.z, w1.x, w1.y, w1.z, r, g, b, 255)

    -- Top Loop
    DrawLine(w5.x, w5.y, w5.z, w6.x, w6.y, w6.z, r, g, b, 255)
    DrawLine(w6.x, w6.y, w6.z, w7.x, w7.y, w7.z, r, g, b, 255)
    DrawLine(w7.x, w7.y, w7.z, w8.x, w8.y, w8.z, r, g, b, 255)
    DrawLine(w8.x, w8.y, w8.z, w5.x, w5.y, w5.z, r, g, b, 255)

    -- Pillars
    DrawLine(w1.x, w1.y, w1.z, w5.x, w5.y, w5.z, r, g, b, 255)
    DrawLine(w2.x, w2.y, w2.z, w6.x, w6.y, w6.z, r, g, b, 255)
    DrawLine(w3.x, w3.y, w3.z, w7.x, w7.y, w7.z, r, g, b, 255)
    DrawLine(w4.x, w4.y, w4.z, w8.x, w8.y, w8.z, r, g, b, 255)
end

---Destroy the tray and all attached items
function Tray:Destroy()
    if DoesEntityExist(self.entity) then
        DeleteEntity(self.entity)
    end

    for _, itemEntity in ipairs(self.items) do
        if DoesEntityExist(itemEntity) then
            DeleteEntity(itemEntity)
        end
    end
    self.items = {}
end

return Tray
