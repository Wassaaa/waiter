---@class Tray
---@field entity number Entity handle
---@field model number Model hash
local Tray = {}
Tray.__index = Tray

---Create a new Tray instance
---@param model string|number Prop model
---@param coords vector3 Spawn position
---@param heading number Heading
---@return Tray|nil
function Tray.New(model, coords, heading)
    local self = setmetatable({}, Tray)
    -- Fix type casting for lint
    self.model = (type(model) == 'string' and joaat(model) or model) --[[@as number]]

    RequestModel(self.model)
    while not HasModelLoaded(self.model) do Wait(0) end

    self.entity = CreateObject(self.model, coords.x, coords.y, coords.z, false, false, false)
    lib.print.info('DEBUG: Tray Entity Created:', self.entity, 'at', coords)
    if self.entity == 0 then
        lib.print.error('ERROR: Failed to create Tray object for model', self.model, 'at', coords)
        return nil
    end
    SetEntityHeading(self.entity, heading)
    FreezeEntityPosition(self.entity, true)

    -- Ensure it sits nicely?
    -- Assuming coords are ground/table z.

    return self
end

---Attach list of items to the tray
---@param items table List of DraggableItems
function Tray:AttachItems(items)
    local trayRot = GetEntityRotation(self.entity, 2)
    lib.print.info('DEBUG: Attaching items to Tray', self.entity)

    for _, item in ipairs(items) do
        local itemEntity = item.entity
        if DoesEntityExist(itemEntity) then
            -- 1. Stop Physics immediately
            FreezeEntityPosition(itemEntity, true)
            SetEntityCollision(itemEntity, false, false)

            -- 2. Calculate offsets
            local itemCoords = GetEntityCoords(itemEntity)
            local itemRot = GetEntityRotation(itemEntity, 2)

            local offset = GetOffsetFromEntityGivenWorldCoords(self.entity, itemCoords.x, itemCoords.y, itemCoords.z)
            local relRot = itemRot - trayRot

            lib.print.info('DEBUG: Attaching Item', itemEntity, 'Offset:', offset, 'Rot:', relRot)

            -- 3. Attach
            -- usage: AttachEntityToEntity(ent1, ent2, bone, x, y, z, rx, ry, rz, p9, softPinning, collision, isPed, vertexIndex, fixedRot)
            AttachEntityToEntity(
                itemEntity, self.entity, 0,
                offset.x, offset.y, offset.z,
                relRot.x, relRot.y, relRot.z,
                false, false, false, false, 0, true
            )
        end
    end
end

---Attach the tray to the player's hand
---@param ped number Ped handle
function Tray:Pickup(ped)
    FreezeEntityPosition(self.entity, false)
    SetEntityCollision(self.entity, false, false) -- Disable collision while carrying? Or keep it?
    -- Usually better to disable collision on carried props to avoid physics freakouts.

    -- Bone 28422 (Right Hand)
    -- Standard Offset for tray hold?
    -- Needs testing, but let's guess standard tray carry.
    -- X=0.0, Y=0.0, Z=0.0, Rot 0,0,0
    AttachEntityToEntity(self.entity, ped, GetPedBoneIndex(ped, 28422),
        0.0, 0.0, -0.2, -- Adjust z
        0.0, 0.0, 0.0,
        true,           -- p9/softPinning?
        true,           -- useSoftPinning
        false,          -- collision
        true,           -- isPed
        1,              -- vertex
        true            -- fixedRot
    )

    -- Animation? Handled by external script or Minigame should trigger it.
    -- We just attach here.
end

return Tray
