---@class DragDrop
local DragDrop = {}

local Raycast = require 'client.lib.raycast'
local Controls = require 'client.lib.controls'

local function DrawEntityBox(entity, r, g, b)
    local min, max = GetModelDimensions(GetEntityModel(entity))
    local corners = {
        GetOffsetFromEntityInWorldCoords(entity, min.x, min.y, min.z),
        GetOffsetFromEntityInWorldCoords(entity, max.x, min.y, min.z),
        GetOffsetFromEntityInWorldCoords(entity, max.x, max.y, min.z),
        GetOffsetFromEntityInWorldCoords(entity, min.x, max.y, min.z),
        GetOffsetFromEntityInWorldCoords(entity, min.x, min.y, max.z),
        GetOffsetFromEntityInWorldCoords(entity, max.x, min.y, max.z),
        GetOffsetFromEntityInWorldCoords(entity, max.x, max.y, max.z),
        GetOffsetFromEntityInWorldCoords(entity, min.x, max.y, max.z),
    }
    local lines = {
        { 1, 2 }, { 2, 3 }, { 3, 4 }, { 4, 1 }, -- Bottom
        { 5, 6 }, { 6, 7 }, { 7, 8 }, { 8, 5 }, -- Top
        { 1, 5 }, { 2, 6 }, { 3, 7 }, { 4, 8 }  -- Vertical
    }
    for _, l in ipairs(lines) do
        DrawLine(corners[l[1]].x, corners[l[1]].y, corners[l[1]].z, corners[l[2]].x, corners[l[2]].y, corners[l[2]].z, r,
            g, b, 255)
    end
end

---@class DraggableItem
---@field entity number Entity handle (Physics Host)
---@field visualEntity number? Visual Entity handle (if proxy used)
---@field key string Unique key for item type (e.g. 'burger')
---@field isDispenser boolean If true, clicking spawns a new item instead of dragging this one
---@field model number? Model hash (required for dispensers)
---@field physicsProxyModel number? Optional proxy model hash

---@class DispenserItem
---@field entity number? Entity handle (nil if empty)
---@field key string Unique key
---@field model number Model hash
---@field physicsProxyModel number? Optional proxy model hash
---@field coords vector3|vector4 Spawn coordinates
---@field lastPickupTime number Last pickup timestamp

---@class DragSession
---@field active boolean
---@field cam number Camera handle
---@field zHeight number Plane Z height
---@field items DraggableItem[] List of active items
---@field dispensers DispenserItem[] List of dispenser items
---@field draggedItem number? Entity handle of currently dragged item
---@field dragOffset vector3 Offset from mouse to item origin
---@field onFinish fun(keys: string[], items: DraggableItem[]) Callback on finish
---@field onCancel fun() Callback on cancel
---@field enableCollision boolean? Enable physics collisions on items
---@field physicsHostModel number? Model hash for physics proxy
---@field cameraMode boolean Is camera control active
---@field lookAt vector3 Camera target
---@field camPos vector3 Current camera position
---@field orbitDist number Distance from target
---@field orbitAngle number Azimuth angle (radians)
---@field orbitPitch number Elevation angle (radians)
---@field debugMode boolean Show debug visuals
---@field dragZOffset number Vertical offset for drag
---@field probeHandle number? Async Raycast Handle
---@field lastHitEntity number? Last entity hit by raycast
---@field dispenserCooldown number Time in ms before refill
---@field dispenserRespawnDist number Safe distance in meters for refill
---@field onDebug fun() Callback for custom debug rendering
local Session = {}
Session.__index = Session

---Start a new Drag & Drop session
---@param config table Configuration { cameraPos, lookAt, zHeight, onFinish, onCancel }
---@return DragSession
function DragDrop.NewSession(config)
    local self = setmetatable({}, Session)

    self.active = false
    self.zHeight = config.zHeight or 0.0
    self.items = {}
    self.dispensers = {}
    self.draggedItem = nil
    self.dragOffset = vector3(0, 0, 0)
    self.onFinish = config.onFinish or function() end
    self.onCancel = config.onCancel or function() end
    self.onDebug = config.onDebug or function() end
    self.enableCollision = config.enableCollision or false
    self.physicsHostModel = config.physicsHostModel
    self.debugMode = false
    self.dragZOffset = 0.0
    self.probeHandle = nil
    self.lastHitEntity = nil
    self.dispenserCooldown = config.dispenserCooldown or 1000
    self.dispenserRespawnDist = config.dispenserRespawnDist or 0.6

    -- Orbit Camera State
    self.cameraMode = false
    self.lookAt = config.lookAt
    self.camPos = config.cameraPos
    local diff = self.camPos - self.lookAt
    self.orbitDist = #diff
    self.orbitAngle = math.atan(diff.y, diff.x)
    self.orbitPitch = math.asin(diff.z / self.orbitDist)

    -- Setup Camera
    self.cam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    SetCamCoord(self.cam, self.camPos.x, self.camPos.y, self.camPos.z)
    PointCamAtCoord(self.cam, self.lookAt.x, self.lookAt.y, self.lookAt.z)

    return self
end

---Internal: Respawn a dispenser prop
function Session:RespawnDispenser(d)
    lib.requestModel(d.model)
    local coords = d.coords
    local prop = CreateObject(d.model, coords.x, coords.y, coords.z, false, false, false)
    FreezeEntityPosition(prop, true)
    SetEntityCollision(prop, true, true)
    if type(coords) == 'vector4' then
        SetEntityHeading(prop, coords.w)
    end
    d.entity = prop
end

---Add a dispenser prop that spawns items
---@param model string|number Model or hash
---@param key string Unique item key (e.g. 'burger')
---@param coords vector3|vector4 Spawn coordinates
---@param physicsProxyModel string|number|nil Optional proxy model
function Session:AddDispenser(model, key, coords, physicsProxyModel)
    local modelHash = type(model) == 'string' and joaat(model) or model
    local proxyHash = nil
    if physicsProxyModel then
        proxyHash = type(physicsProxyModel) == 'string' and joaat(physicsProxyModel) or physicsProxyModel
    end

    local d = {
        model = modelHash,
        key = key,
        coords = coords,
        physicsProxyModel = proxyHash,
        entity = nil,
        lastPickupTime = 0
    }
    lib.print.debug('Adding Dispenser', key, coords)
    self:RespawnDispenser(d)
    table.insert(self.dispensers, d)
end

---Internal: Prepare dispenser prop for physics and add to Items
function Session:ConvertDispenserToItem(d)
    if not d.entity then return nil end
    local entity = d.entity

    -- Cleanup Dispenser State
    d.entity = nil
    d.lastPickupTime = GetGameTimer()

    local finalEntity = entity
    local finalVisual = nil

    if self.enableCollision then
        if d.physicsProxyModel then
            -- Attach Proxy logic
            local host = self:AttachProxy(entity, d.physicsProxyModel)
            finalEntity = host
            finalVisual = entity
        else
            -- Direct Physics
            SetEntityDynamic(entity, true)
            SetEntityCollision(entity, true, true)
            SetActivateObjectPhysicsAsSoonAsItIsUnfrozen(entity, true)
            FreezeEntityPosition(entity, false)
        end
    end

    -- Apply Init Rotation
    SetEntityRotation(finalEntity, 0, 0, math.random(0, 360) * 1.0, 2, true)

    self:AddItem(finalEntity, d.key, finalVisual)
    return finalEntity
end

---Internal: Refill empty dispensers if conditions met
function Session:UpdateDispensers(hitPos)
    local now = GetGameTimer()
    for _, d in ipairs(self.dispensers) do
        if not d.entity then
            if (now - d.lastPickupTime) > self.dispenserCooldown then
                local safeToRespawn = true
                if hitPos then
                    local dist = #(hitPos - vector3(d.coords.x, d.coords.y, d.coords.z))
                    if dist < self.dispenserRespawnDist then safeToRespawn = false end
                end

                if safeToRespawn then
                    self:RespawnDispenser(d)
                end
            end
        end
    end
end

---Add an existing item to the session
---@param entity number Entity handle (Physics Host)
---@param key string Item key
---@param visualEntity number? Optional visual entity attached to host
function Session:AddItem(entity, key, visualEntity)
    -- Apply physics settings if enabled
    if self.enableCollision then
        SetEntityDynamic(entity, true)
        SetEntityHasGravity(entity, true)
        SetActivateObjectPhysicsAsSoonAsItIsUnfrozen(entity, true)
        FreezeEntityPosition(entity, false)
    else
        -- If collision disabled (Physics), still allow raycast but freeze
        SetEntityDynamic(entity, false)
        FreezeEntityPosition(entity, true)
    end

    table.insert(self.items, {
        entity = entity,
        visualEntity = visualEntity,
        key = key,
        isDispenser = false
    })
    lib.print.debug('Added Item', key, entity)
end

---Internal: Spawn helper for proxy
---@param visualEntity number The existing visual entity to attach
---@param hostModel number? Model hash for physics proxy (optional)
---@return number hostEntity
function Session:AttachProxy(visualEntity, hostModel)
    local model = hostModel or self.physicsHostModel or joaat('prop_cs_burger_01')
    lib.requestModel(model)

    local coords = GetEntityCoords(visualEntity)

    -- Spawn Physics Host
    local host = CreateObject(model, coords.x, coords.y, coords.z, false, false, false)
    SetEntityVisible(host, false, false) -- Invisible physics body

    -- Disable collision on visual entity so it doesn't fight the host
    SetEntityCollision(visualEntity, false, false)

    -- Calculate Z-Offset to align the bottom of the visual prop with the bottom of the host
    local minV, _ = GetModelDimensions(GetEntityModel(visualEntity))
    local minH, _ = GetModelDimensions(model)
    local zOffset = minH.z - minV.z

    -- Attach Visual to Host
    AttachEntityToEntity(visualEntity, host, 0, 0.0, 0.0, zOffset, 0.0, 0.0, 0.0, false, false, false, false, 2, true)

    return host
end

---Internal: Spawn a new item from a dispenser
---@param model number Model hash
---@param coords vector3 Spawn coords
---@param key string
---@param physicsProxyModel number|nil Optional proxy model
---@param rotation vector3|nil Optional rotation (degrees)
---@return number entity (The physics host)
function Session:SpawnItem(model, coords, key, physicsProxyModel, rotation)
    lib.requestModel(model)

    -- Spawn the visual prop
    local prop = CreateObject(model, coords.x, coords.y, coords.z, false, false, false)

    local finalEntity = prop
    local finalVisual = nil

    if self.enableCollision then
        if physicsProxyModel then
            -- Configured to use a specific Physics Proxy
            local host = self:AttachProxy(prop, physicsProxyModel)
            finalEntity = host
            finalVisual = prop
        else
            -- Configured to use Direct Physics
            SetEntityDynamic(prop, true)
            SetEntityCollision(prop, true, true)
            SetActivateObjectPhysicsAsSoonAsItIsUnfrozen(prop, true)
            FreezeEntityPosition(prop, false)
        end
    end

    -- Apply Rotation to governing entity
    if rotation then
        SetEntityRotation(finalEntity, rotation.x, rotation.y, rotation.z, 2, true)
    else
        SetEntityRotation(finalEntity, 0, 0, 0, 2, true)
    end

    self:AddItem(finalEntity, key, finalVisual)
    return finalEntity
end

---Internal: Disable all relevant controls
function Session:DisableControls()
    DisableControlAction(0, Controls.LOOK_LR, true)
    DisableControlAction(0, Controls.LOOK_UD, true)
    DisableControlAction(0, Controls.ATTACK, true)
    DisableControlAction(0, Controls.AIM, true)
    DisableControlAction(0, Controls.MOVE_LR, true)
    DisableControlAction(0, Controls.MOVE_UD, true)
    DisableControlAction(0, Controls.SKIP_CUTSCENE, true)
    DisableControlAction(0, Controls.CELLPHONE_CANCEL, true)
    DisableControlAction(0, Controls.FRONTEND_PAUSE_ALTERNATE, true)
    DisableControlAction(0, Controls.FRONTEND_CANCEL, true)
    DisableControlAction(0, Controls.JUMP, true)
    DisableControlAction(0, Controls.DETONATE, true)
    DisableControlAction(0, Controls.VEH_HEADLIGHT, true)
    DisableControlAction(0, Controls.CURSOR_SCROLL_UP, true)
    DisableControlAction(0, Controls.CURSOR_SCROLL_DOWN, true)
end

---Internal: Handle Debug Mode logic
function Session:HandleDebug()
    if IsDisabledControlJustPressed(0, Controls.VEH_HEADLIGHT) then
        self.debugMode = not self.debugMode
        for _, item in ipairs(self.items) do
            if item.visualEntity then
                SetEntityVisible(item.entity, self.debugMode, false)
                SetEntityAlpha(item.entity, self.debugMode and 150 or 255, false)

                -- Ensure visual remains visible
                SetEntityVisible(item.visualEntity, true, false)
                ResetEntityAlpha(item.visualEntity)
            end
        end
    end

    if self.debugMode then
        self:onDebug()

        for _, item in ipairs(self.items) do
            if item.visualEntity then
                DrawEntityBox(item.entity, 255, 0, 0)       -- Host (Red)
                DrawEntityBox(item.visualEntity, 0, 255, 0) -- Visual (Green)
                -- Link line
                local p1 = GetEntityCoords(item.entity)
                local p2 = GetEntityCoords(item.visualEntity)
                DrawLine(p1.x, p1.y, p1.z, p2.x, p2.y, p2.z, 255, 255, 0, 255)
            else
                DrawEntityBox(item.entity, 0, 0, 255) -- Direct (Blue)
            end
        end
    end
end

---Internal: Handle Camera Mode logic
---@return boolean active Whether camera mode is currently controlling input
function Session:HandleCamera()
    if IsDisabledControlJustPressed(0, Controls.DETONATE) then
        self.cameraMode = not self.cameraMode
    end

    if self.cameraMode then
        local sensitivity = 1.0
        local dx = GetDisabledControlNormal(0, Controls.LOOK_LR) * sensitivity
        local dy = GetDisabledControlNormal(0, Controls.LOOK_UD) * sensitivity

        self.orbitAngle = self.orbitAngle - dx
        self.orbitPitch = math.max(0.1, math.min(1.5, self.orbitPitch + dy))

        local x = self.lookAt.x + self.orbitDist * math.cos(self.orbitPitch) * math.cos(self.orbitAngle)
        local y = self.lookAt.y + self.orbitDist * math.cos(self.orbitPitch) * math.sin(self.orbitAngle)
        local z = self.lookAt.z + self.orbitDist * math.sin(self.orbitPitch)

        self.camPos = vector3(x, y, z)
        SetCamCoord(self.cam, x, y, z)
        PointCamAtCoord(self.cam, self.lookAt.x, self.lookAt.y, self.lookAt.z)
        return true
    end
    return false
end

---Internal: Handle global session controls (Finish/Cancel)
function Session:HandleSessionControls()
    -- Finish
    if IsDisabledControlJustReleased(0, Controls.JUMP) then -- Space
        local resultKeys = {}
        for _, item in ipairs(self.items) do
            if DoesEntityExist(item.entity) then
                table.insert(resultKeys, item.key)
            end
        end
        self.onFinish(resultKeys, self.items)
        self:Stop()
    end

    -- Cancel
    if IsDisabledControlJustReleased(0, Controls.FRONTEND_PAUSE_ALTERNATE) then -- ESC
        self:Stop()
        self.onCancel()
    end
end

---Internal: Handle Left Click
function Session:HandleClick(hitPos, hitEntity)
    local bestDist = 0.15
    local pickedDispenser = nil
    local pickedItem = nil

    -- 1. Check Raycast Hit
    if hitEntity and hitEntity > 0 then
        -- Check Dispensers
        for _, d in ipairs(self.dispensers) do
            if d.entity == hitEntity then
                pickedDispenser = d
                break
            end
        end
        -- Check Items
        if not pickedDispenser then
            for _, item in ipairs(self.items) do
                if item.entity == hitEntity or item.visualEntity == hitEntity then
                    pickedItem = item.entity -- Store Entity Handle
                    break
                end
            end
        end
    end

    -- Execute Pick
    if pickedDispenser then
        local newItem = self:ConvertDispenserToItem(pickedDispenser)
        self.draggedItem = newItem
        self.dragOffset = vector3(0, 0, 0)
        self.dragZOffset = 0.0
    elseif pickedItem then
        self.draggedItem = pickedItem
        self.dragOffset = GetEntityCoords(pickedItem) - hitPos
        self.dragZOffset = 0.0
    end
end

---Internal: Handle Drag Update
function Session:HandleDrag(hitPos)
    -- Handle Scroll for Z-Axis
    if IsDisabledControlJustPressed(0, Controls.CURSOR_SCROLL_UP) then
        self.dragZOffset = self.dragZOffset + 0.05
    elseif IsDisabledControlJustPressed(0, Controls.CURSOR_SCROLL_DOWN) then
        self.dragZOffset = self.dragZOffset - 0.05
    end

    if DoesEntityExist(self.draggedItem) then
        local target = hitPos + self.dragOffset
        local hoverHeight = self.enableCollision and 0.15 or 0.0
        target = vector3(target.x, target.y, self.zHeight + hoverHeight + self.dragZOffset)

        if self.enableCollision then
            local current = GetEntityCoords(self.draggedItem)
            local diff = target - current
            local responsiveness = 20.0
            local velocity = diff * responsiveness
            SetEntityVelocity(self.draggedItem, velocity.x, velocity.y, velocity.z)

            -- Proportional controller to maintain upright orientation
            local rot = GetEntityRotation(self.draggedItem, 2)
            local angVel = GetEntityRotationVelocity(self.draggedItem)

            -- Tune these values for "smooth but upright"
            local uprightStrength = 0.2 -- Strength of correction
            local yawDamp = 0.1         -- Dampen Yaw spin

            -- Calculate desired angular velocity to correct error
            local targetVelX = (0.0 - rot.x) * uprightStrength
            local targetVelY = (0.0 - rot.y) * uprightStrength

            -- Apply (overwriting current works best for stability in this loop)
            -- We keep Z velocity low to prevent spinning but allow some automatic settling
            SetEntityAngularVelocity(self.draggedItem, targetVelX, targetVelY, angVel.z * yawDamp)
        else
            SetEntityCoords(self.draggedItem, target.x, target.y, target.z, false, false, false, false)
            local curRot = GetEntityRotation(self.draggedItem, 2)
            SetEntityRotation(self.draggedItem, 0, 0, curRot.z, 2, true)
        end
    else
        self.draggedItem = nil
    end
end

---Internal: Handle Release
function Session:HandleRelease()
    if self.draggedItem and self.enableCollision then
        local vel = GetEntityVelocity(self.draggedItem)
        SetEntityVelocity(self.draggedItem, vel.x * 0.5, vel.y * 0.5, vel.z * 0.5)
    end
    self.draggedItem = nil
end

---Internal: Handle Delete (Right Click)
function Session:HandleDelete(hitPos, hitEntity)
    local matchIndex = -1

    if hitEntity and hitEntity > 0 then
        for i, item in ipairs(self.items) do
            if item.entity == hitEntity or item.visualEntity == hitEntity then
                matchIndex = i
                break
            end
        end
    end

    -- Strict Raycast check only.
    if matchIndex ~= -1 then
        local item = self.items[matchIndex]
        if DoesEntityExist(item.entity) then DeleteEntity(item.entity) end
        if item.visualEntity and DoesEntityExist(item.visualEntity) then DeleteEntity(item.visualEntity) end
        table.remove(self.items, matchIndex)
    end
end

---Internal: Handle Mouse Interaction (Drag & Drop)
function Session:HandleInteraction()
    SetMouseCursorActiveThisFrame()

    local camCoords = GetCamCoord(self.cam)
    local _, dir = Raycast.FromScreen()
    local hitPos = Raycast.IntersectPlane(camCoords, dir, self.zHeight)

    self:UpdateDispensers(hitPos)

    -- Async Raycast Probe (Only scan when not holding item)
    if not self.draggedItem then
        if not self.probeHandle then
            -- Start new probe (Flags: 16=Objects, Options: 7=Default)
            self.probeHandle = Raycast.StartProbe(camCoords, dir, 20.0, 16, cache.ped, 7)
        else
            local retval, hit, _, _, entityHit = Raycast.CheckProbe(self.probeHandle)
            if retval ~= 1 then        -- Not Pending (0 or 2)
                self.lastHitEntity = (hit and entityHit > 0) and entityHit or nil
                self.probeHandle = nil -- Clear so we can start next frame
            end
        end
    else
        self.lastHitEntity = nil
        self.probeHandle = nil
    end

    if hitPos then
        -- Handle Click (Pick Up / Spawn)
        if IsDisabledControlJustPressed(0, Controls.ATTACK) then
            self:HandleClick(hitPos, self.lastHitEntity)
        end

        -- Handle Dragging
        if IsDisabledControlPressed(0, Controls.ATTACK) and self.draggedItem then
            self:HandleDrag(hitPos)
        end

        -- Handle Release
        if IsDisabledControlJustReleased(0, Controls.ATTACK) then
            self:HandleRelease()
        end

        -- Handle Right Click (Delete)
        if IsDisabledControlJustPressed(0, Controls.AIM) then
            self:HandleDelete(hitPos, self.lastHitEntity)
        end
    end
end

---Internal: Handle input tick
function Session:ProcessInput()
    self:DisableControls()
    self:HandleDebug()
    self:HandleSessionControls()

    if self:HandleCamera() then
        return
    end

    self:HandleInteraction()
end

---Start the session loop
function Session:Start()
    if self.active then return end
    self.active = true

    SetCamActive(self.cam, true)
    RenderScriptCams(true, true, 1000, true, true)

    -- Freeze player
    FreezeEntityPosition(cache.ped, true)

    CreateThread(function()
        while self.active do
            self:ProcessInput()
            Wait(0)
        end
    end)
end

---Stop session and cleanup
---@param preserveItems boolean? If true, items are not deleted (ownership transferred)
function Session:Stop(preserveItems)
    self.active = false

    RenderScriptCams(false, true, 1000, true, true)
    if DoesEntityExist(self.cam) then DestroyCam(self.cam, false) end

    -- Cleanup Dispensers
    for _, d in ipairs(self.dispensers) do
        if DoesEntityExist(d.entity) then DeleteEntity(d.entity) end
    end

    -- Cleanup Items (Caller responsibility? No, session usually owns them unless transferred)
    -- For now, we delete them unless preserved (transferred to tray)
    if not preserveItems then
        for _, item in ipairs(self.items) do
            if DoesEntityExist(item.entity) then DeleteEntity(item.entity) end
            if item.visualEntity and DoesEntityExist(item.visualEntity) then DeleteEntity(item.visualEntity) end
        end
    end

    self.dispensers = {}
    self.items = {}

    FreezeEntityPosition(cache.ped, false)
end

return DragDrop
