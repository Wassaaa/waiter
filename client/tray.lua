-- Tray Helper Functions
local sharedConfig = require 'config.shared'

-- ============================================================================
-- Tray API
-- ============================================================================

function ModifyHand(action, item)
  TriggerServerEvent('waiter:server:modifyTray', action, item)
end

-- Helper to get current tray contents (from statebag)
function GetMyTray()
  return LocalPlayer.state.waiterTray or {}
end

---Get the number of available tray slots (can be expanded based on skill later)
---@param skillLevel number? Optional skill level (for future use)
---@return number slots Number of available slots
function GetAvailableTraySlots(skillLevel)
  -- Future: return more slots based on skill
  -- if skillLevel and skillLevel >= 5 then return 5 end
  -- if skillLevel and skillLevel >= 3 then return 4 end
  return #sharedConfig.Tray.slots
end

---Get slot position and rotation on tray
---@param slotIndex number 1-based slot index
---@return table|nil slot {x, y, z, rx, ry, rz} or nil if invalid
function GetTraySlot(slotIndex)
  local slot = sharedConfig.Tray.slots[slotIndex]
  if not slot then return nil end

  -- Return with default rotations if not specified
  return {
    x = slot.x,
    y = slot.y,
    z = slot.z,
    rx = slot.rx or 0.0,
    ry = slot.ry or 0.0,
    rz = slot.rz or 0.0,
  }
end

---Get item offset adjustments
---@param itemKey string Item key from config
---@return table offset {x, y, z, rx, ry, rz}
function GetItemOffset(itemKey)
  local itemData = sharedConfig.Items[itemKey]
  local defaults = sharedConfig.Tray.defaultItemOffset
  local itemOffset = itemData and itemData.offset or {}

  return {
    x = itemOffset.x or defaults.x,
    y = itemOffset.y or defaults.y,
    z = itemOffset.z or defaults.z,
    rx = itemOffset.rx or defaults.rx,
    ry = itemOffset.ry or defaults.ry,
    rz = itemOffset.rz or defaults.rz,
  }
end

---Calculate final position for item on tray (slot + item offset)
---@param slotIndex number 1-based slot index
---@param itemKey string Item key for offset lookup
---@return table|nil position {x, y, z, rx, ry, rz} or nil if invalid slot
function GetItemPositionOnTray(slotIndex, itemKey)
  local slot = GetTraySlot(slotIndex)
  if not slot then return nil end

  local offset = GetItemOffset(itemKey)

  return {
    x = slot.x + offset.x,
    y = slot.y + offset.y,
    z = slot.z + offset.z,
    rx = slot.rx + offset.rx,
    ry = slot.ry + offset.ry,
    rz = slot.rz + offset.rz,
  }
end

---Get item prop hash from config
---@param itemKey string Item key
---@return number|nil hash Model hash or nil
function GetItemPropHash(itemKey)
  local itemData = sharedConfig.Items[itemKey]
  if not itemData or not itemData.prop then return nil end
  return joaat(itemData.prop)
end

---Spawn and attach tray prop to ped
---@param ped number Ped handle
---@return number|nil trayProp Entity handle or nil on failure
function SpawnTrayProp(ped)
  if not DoesEntityExist(ped) then return nil end

  local trayConfig = sharedConfig.Tray
  local hash = joaat(trayConfig.prop)

  lib.requestModel(hash)
  local trayProp = CreateObject(hash, 0, 0, 0, true, true, false)

  if not DoesEntityExist(trayProp) then return nil end

  local boneIndex = GetPedBoneIndex(ped, trayConfig.bone)
  local off = trayConfig.offset
  local rot = trayConfig.rotation

  AttachEntityToEntity(
    trayProp, ped, boneIndex,
    off.x, off.y, off.z,
    rot.x, rot.y, rot.z,
    true, true, false, true, 1, true
  )

  return trayProp
end

---Spawn and attach item prop to tray at specific slot
---@param trayProp number Tray entity handle
---@param slotIndex number 1-based slot index
---@param itemKey string Item key from config
---@return number|nil itemProp Entity handle or nil on failure
function SpawnItemOnTray(trayProp, slotIndex, itemKey)
  if not DoesEntityExist(trayProp) then return nil end

  local hash = GetItemPropHash(itemKey)
  if not hash then return nil end

  local pos = GetItemPositionOnTray(slotIndex, itemKey)
  if not pos then return nil end

  lib.requestModel(hash)
  local itemProp = CreateObject(hash, 0, 0, 0, true, true, false)

  if not DoesEntityExist(itemProp) then return nil end

  AttachEntityToEntity(
    itemProp, trayProp, 0,
    pos.x, pos.y, pos.z,
    pos.rx, pos.ry, pos.rz,
    true, true, false, true, 1, true
  )

  return itemProp
end

---Match tray items with customer order
---@param tray table Current tray items
---@param order table Customer order (will be modified)
---@return table matched Items that matched the order
---@return number count Number of matches
function MatchTrayWithOrder(tray, order)
  local matched = {}

  -- Loop backwards through tray
  for i = #tray, 1, -1 do
    local heldItem = tray[i]

    -- Check if customer needs this specific item
    for orderIdx, neededItem in ipairs(order) do
      if neededItem == heldItem then
        table.remove(order, orderIdx)
        table.insert(matched, heldItem)
        break
      end
    end
  end

  return matched, #matched
end

-- ============================================================================
-- Debug / Tuning Commands
-- ============================================================================

if GetConvarInt('waiter_debug', 0) == 1 then
  -- Sample items to fill other slots during tuning
  local sampleItems = { 'burger', 'drink', 'fries' }

  local tuneState = {
    active = false,
    itemKey = nil,
    slotIndex = 1,
    offset = { x = 0, y = 0, z = 0, rx = 0, ry = 0, rz = 0 },
    trayProp = nil,
    itemProp = nil,  -- The item being tuned (gizmo target)
    otherItems = {}, -- Other slot items (just for visualization)
  }

  ---Get world position for item based on tray position and local offset
  ---@param trayProp number Tray entity handle
  ---@param slotIndex number Slot index
  ---@param offset table Local offset {x, y, z}
  ---@return vector3 worldPos
  local function getItemWorldPosition(trayProp, slotIndex, offset)
    local slot = GetTraySlot(slotIndex)
    if not slot then return GetEntityCoords(trayProp) end

    -- Use GetOffsetFromEntityInWorldCoords to handle local->world transform
    local localX = slot.x + offset.x
    local localY = slot.y + offset.y
    local localZ = slot.z + offset.z

    return GetOffsetFromEntityInWorldCoords(trayProp, localX, localY, localZ)
  end

  ---Calculate local offset from world position relative to tray
  ---@param trayProp number Tray entity handle
  ---@param worldPos vector3 World position of item
  ---@param slotIndex number Slot index
  ---@return table offset {x, y, z}
  local function getLocalOffsetFromWorld(trayProp, worldPos, slotIndex)
    local slot = GetTraySlot(slotIndex)
    if not slot then return { x = 0, y = 0, z = 0 } end

    -- Use GetOffsetFromEntityGivenWorldCoords to handle world->local transform
    local localCoords = GetOffsetFromEntityGivenWorldCoords(trayProp, worldPos.x, worldPos.y, worldPos.z)

    -- Subtract slot base position to get offset
    return {
      x = localCoords.x - slot.x,
      y = localCoords.y - slot.y,
      z = localCoords.z - slot.z,
    }
  end

  local function refreshTunePreview()
    if not tuneState.active then return end

    local ped = PlayerPedId()
    if not DoesEntityExist(ped) then return end

    -- Clean old props
    if tuneState.itemProp and DoesEntityExist(tuneState.itemProp) then
      DeleteEntity(tuneState.itemProp)
    end
    for _, prop in ipairs(tuneState.otherItems) do
      if DoesEntityExist(prop) then DeleteEntity(prop) end
    end
    tuneState.otherItems = {}
    if tuneState.trayProp and DoesEntityExist(tuneState.trayProp) then
      DeleteEntity(tuneState.trayProp)
    end

    -- Play tray animation and spawn attached tray (real gameplay setup)
    local clientConfig = require 'config.client'
    PlayAnimUpper(ped, clientConfig.Anims.Tray.dict, clientConfig.Anims.Tray.anim, true)
    Wait(300)

    -- Spawn tray attached to player (real orientation)
    tuneState.trayProp = SpawnTrayProp(ped)
    if not DoesEntityExist(tuneState.trayProp) then return end

    -- Immediately capture tray position and detach/freeze BEFORE spawning items
    -- This prevents items sliding due to player idle movements
    local trayPos = GetEntityCoords(tuneState.trayProp)
    local trayRot = GetEntityRotation(tuneState.trayProp, 2)

    DetachEntity(tuneState.trayProp, false, false)
    SetEntityCoords(tuneState.trayProp, trayPos.x, trayPos.y, trayPos.z, false, false, false, false)
    SetEntityRotation(tuneState.trayProp, trayRot.x, trayRot.y, trayRot.z, 2, true)
    FreezeEntityPosition(tuneState.trayProp, true)

    -- Clear player animation now that tray is detached
    ClearPedTasks(ped)

    -- NOW spawn items on the frozen tray
    tuneState.itemProp = SpawnItemOnTray(tuneState.trayProp, tuneState.slotIndex, tuneState.itemKey)
    if not DoesEntityExist(tuneState.itemProp) then return end

    -- Spawn sample items in other slots for visualization
    local maxSlots = GetAvailableTraySlots()
    for i = 1, maxSlots do
      if i ~= tuneState.slotIndex then
        local sampleItem = sampleItems[((i - 1) % #sampleItems) + 1]
        local otherProp = SpawnItemOnTray(tuneState.trayProp, i, sampleItem)
        if otherProp then
          table.insert(tuneState.otherItems, otherProp)
        end
      end
    end

    -- Detach items from tray (they're attached by SpawnItemOnTray)
    local itemPos = GetEntityCoords(tuneState.itemProp)
    local itemRot = GetEntityRotation(tuneState.itemProp, 2)
    DetachEntity(tuneState.itemProp, false, false)
    SetEntityCoords(tuneState.itemProp, itemPos.x, itemPos.y, itemPos.z, false, false, false, false)
    SetEntityRotation(tuneState.itemProp, itemRot.x, itemRot.y, itemRot.z, 2, true)
    FreezeEntityPosition(tuneState.itemProp, true)
    SetEntityCollision(tuneState.itemProp, false, false)

    -- Detach and freeze other items
    for _, prop in ipairs(tuneState.otherItems) do
      local pos = GetEntityCoords(prop)
      local rot = GetEntityRotation(prop, 2)
      DetachEntity(prop, false, false)
      SetEntityCoords(prop, pos.x, pos.y, pos.z, false, false, false, false)
      SetEntityRotation(prop, rot.x, rot.y, rot.z, 2, true)
      FreezeEntityPosition(prop, true)
      SetEntityCollision(prop, false, false)
    end
  end

  local function cleanupTunePreview()
    -- Delete main props
    if tuneState.itemProp and DoesEntityExist(tuneState.itemProp) then
      DeleteEntity(tuneState.itemProp)
    end
    -- Delete other items
    for _, prop in ipairs(tuneState.otherItems) do
      if DoesEntityExist(prop) then DeleteEntity(prop) end
    end
    tuneState.otherItems = {}
    if tuneState.trayProp and DoesEntityExist(tuneState.trayProp) then
      DeleteEntity(tuneState.trayProp)
    end
    tuneState.itemProp = nil
    tuneState.trayProp = nil
  end

  local function printFinalOffset(itemKey, off)
    print('========== FINAL OFFSET ==========')
    print(('Item: %s'):format(itemKey))

    -- Build minimal offset string (4 decimal places for position, 1 for rotation)
    local parts = {}
    if math.abs(off.x) > 0.0001 then table.insert(parts, ('x = %.4f'):format(off.x)) end
    if math.abs(off.y) > 0.0001 then table.insert(parts, ('y = %.4f'):format(off.y)) end
    if math.abs(off.z) > 0.0001 then table.insert(parts, ('z = %.4f'):format(off.z)) end
    if math.abs(off.rx) > 0.1 then table.insert(parts, ('rx = %.1f'):format(off.rx)) end
    if math.abs(off.ry) > 0.1 then table.insert(parts, ('ry = %.1f'):format(off.ry)) end
    if math.abs(off.rz) > 0.1 then table.insert(parts, ('rz = %.1f'):format(off.rz)) end

    if #parts > 0 then
      print('offset = { ' .. table.concat(parts, ', ') .. ' },')
    else
      print('offset = {},  -- no adjustment needed')
    end
    print('==================================')
  end

  -- /tuneitem <itemKey> [slotIndex] - Tune item offset with gizmo
  RegisterCommand('tuneitem', function(_, args)
    local itemKey = args[1]
    local slotIndex = tonumber(args[2]) or 1

    if not itemKey then
      print('Usage: /tuneitem <itemKey> [slotIndex]')
      print('Available items: burger, fries, drink')
      return
    end

    if not sharedConfig.Items[itemKey] then
      print('Invalid item key: ' .. itemKey)
      return
    end

    -- Load current offset from config as starting point
    local currentOffset = GetItemOffset(itemKey)

    tuneState.active = true
    tuneState.itemKey = itemKey
    tuneState.slotIndex = slotIndex
    tuneState.offset = {
      x = currentOffset.x,
      y = currentOffset.y,
      z = currentOffset.z,
      rx = currentOffset.rx,
      ry = currentOffset.ry,
      rz = currentOffset.rz,
    }

    -- Spawn preview
    refreshTunePreview()

    if not tuneState.trayProp or not tuneState.itemProp then
      print('Failed to spawn preview props')
      cleanupTunePreview()
      tuneState.active = false
      return
    end

    lib.notify({ description = 'Gizmo: W=move, R=rotate, G=cursor, Enter=done', type = 'info' })

    -- Record starting position before gizmo
    local startPos = GetEntityCoords(tuneState.itemProp)
    local startRot = GetEntityRotation(tuneState.itemProp, 2)

    -- Use gizmo (blocks until Enter pressed)
    local result = exports.object_gizmo:useGizmo(tuneState.itemProp)

    if result and result.position then
      -- Convert start and end positions to LOCAL coordinates relative to tray
      local startLocal = GetOffsetFromEntityGivenWorldCoords(tuneState.trayProp, startPos.x, startPos.y, startPos.z)
      local endLocal = GetOffsetFromEntityGivenWorldCoords(tuneState.trayProp, result.position.x, result.position.y,
        result.position.z)

      -- Calculate delta in LOCAL space
      local deltaX = endLocal.x - startLocal.x
      local deltaY = endLocal.y - startLocal.y
      local deltaZ = endLocal.z - startLocal.z

      -- Add local delta to original offset
      tuneState.offset.x = tuneState.offset.x + deltaX
      tuneState.offset.y = tuneState.offset.y + deltaY
      tuneState.offset.z = tuneState.offset.z + deltaZ

      -- Handle rotation delta if provided
      if result.rotation then
        tuneState.offset.rx = tuneState.offset.rx + (result.rotation.x - startRot.x)
        tuneState.offset.ry = tuneState.offset.ry + (result.rotation.y - startRot.y)
        tuneState.offset.rz = tuneState.offset.rz + (result.rotation.z - startRot.z)
      end
    end

    -- Print final values
    printFinalOffset(tuneState.itemKey, tuneState.offset)

    -- Cleanup
    cleanupTunePreview()
    tuneState.active = false
    tuneState.itemKey = nil

    lib.notify({ description = 'Tuning complete. Check console.', type = 'success' })
  end, false)

  -- ============================================================================
  -- Slot Tuning
  -- ============================================================================

  local slotTuneState = {
    active = false,
    slotIndex = 1,
    sampleItem = 'burger',
    slotPos = { x = 0, y = 0, z = 0, rx = 0, ry = 0, rz = 0 },
    trayProp = nil,
    itemProp = nil,  -- The slot item being tuned (gizmo target)
    otherItems = {}, -- Other slot items (just for visualization)
  }

  local function cleanupSlotTunePreview()
    if slotTuneState.itemProp and DoesEntityExist(slotTuneState.itemProp) then
      DeleteEntity(slotTuneState.itemProp)
    end
    for _, prop in ipairs(slotTuneState.otherItems) do
      if DoesEntityExist(prop) then DeleteEntity(prop) end
    end
    slotTuneState.otherItems = {}
    if slotTuneState.trayProp and DoesEntityExist(slotTuneState.trayProp) then
      DeleteEntity(slotTuneState.trayProp)
    end
    slotTuneState.itemProp = nil
    slotTuneState.trayProp = nil
  end

  local function refreshSlotTunePreview()
    if not slotTuneState.active then return end

    local ped = PlayerPedId()
    if not DoesEntityExist(ped) then return end

    -- Clean old props
    cleanupSlotTunePreview()

    -- Play tray animation and spawn attached tray
    local clientConfig = require 'config.client'
    PlayAnimUpper(ped, clientConfig.Anims.Tray.dict, clientConfig.Anims.Tray.anim, true)
    Wait(300)

    -- Spawn tray attached to player
    slotTuneState.trayProp = SpawnTrayProp(ped)
    if not DoesEntityExist(slotTuneState.trayProp) then return end

    -- Immediately capture tray position and detach/freeze BEFORE spawning items
    -- This prevents items sliding due to player idle movements
    local trayPos = GetEntityCoords(slotTuneState.trayProp)
    local trayRot = GetEntityRotation(slotTuneState.trayProp, 2)

    DetachEntity(slotTuneState.trayProp, false, false)
    SetEntityCoords(slotTuneState.trayProp, trayPos.x, trayPos.y, trayPos.z, false, false, false, false)
    SetEntityRotation(slotTuneState.trayProp, trayRot.x, trayRot.y, trayRot.z, 2, true)
    FreezeEntityPosition(slotTuneState.trayProp, true)

    -- Clear player animation now that tray is detached
    ClearPedTasks(ped)

    -- NOW spawn items on the frozen tray

    -- Spawn items in OTHER slots first (using normal SpawnItemOnTray with offsets)
    local maxSlots = GetAvailableTraySlots()
    for i = 1, maxSlots do
      if i ~= slotTuneState.slotIndex then
        local otherSample = sampleItems[((i - 1) % #sampleItems) + 1]
        local otherProp = SpawnItemOnTray(slotTuneState.trayProp, i, otherSample)
        if otherProp then
          table.insert(slotTuneState.otherItems, otherProp)
        end
      end
    end

    -- Spawn the slot being tuned at RAW slot position (no item offset)
    local itemHash = GetItemPropHash(slotTuneState.sampleItem)
    if not itemHash then return end

    lib.requestModel(itemHash)

    local pos = slotTuneState.slotPos
    local itemWorldPos = GetOffsetFromEntityInWorldCoords(slotTuneState.trayProp, pos.x, pos.y, pos.z)

    slotTuneState.itemProp = CreateObject(itemHash, itemWorldPos.x, itemWorldPos.y, itemWorldPos.z, false, false, false)
    if not DoesEntityExist(slotTuneState.itemProp) then return end

    -- Apply tray rotation + slot rotation offset
    SetEntityRotation(slotTuneState.itemProp, trayRot.x + pos.rx, trayRot.y + pos.ry, trayRot.z + pos.rz, 2, true)
    FreezeEntityPosition(slotTuneState.itemProp, true)
    SetEntityCollision(slotTuneState.itemProp, false, false)

    -- Detach and freeze other items
    for _, prop in ipairs(slotTuneState.otherItems) do
      local propPos = GetEntityCoords(prop)
      local propRot = GetEntityRotation(prop, 2)
      DetachEntity(prop, false, false)
      SetEntityCoords(prop, propPos.x, propPos.y, propPos.z, false, false, false, false)
      SetEntityRotation(prop, propRot.x, propRot.y, propRot.z, 2, true)
      FreezeEntityPosition(prop, true)
      SetEntityCollision(prop, false, false)
    end
  end

  local function printSlotPosition(slotIndex, pos)
    print('========== SLOT POSITION ==========')
    print(('Slot: %d'):format(slotIndex))

    -- Build position + rotation string
    local parts = { ('x = %.4f'):format(pos.x), ('y = %.4f'):format(pos.y), ('z = %.4f'):format(pos.z) }

    -- Only include rotation if non-zero
    if math.abs(pos.rx) > 0.1 then table.insert(parts, ('rx = %.1f'):format(pos.rx)) end
    if math.abs(pos.ry) > 0.1 then table.insert(parts, ('ry = %.1f'):format(pos.ry)) end
    if math.abs(pos.rz) > 0.1 then table.insert(parts, ('rz = %.1f'):format(pos.rz)) end

    print('{ ' .. table.concat(parts, ', ') .. ' },')
    print('===================================')
  end

  -- /tuneslot <slotIndex> [sampleItem] - Tune slot position on tray
  RegisterCommand('tuneslot', function(_, args)
    local slotIndex = tonumber(args[1])
    local sampleItem = args[2] or 'burger'

    if not slotIndex then
      print('Usage: /tuneslot <slotIndex> [sampleItem]')
      print('Example: /tuneslot 1 burger')
      print('Example: /tuneslot 4 drink  (for new slot)')
      return
    end

    if not sharedConfig.Items[sampleItem] or not sharedConfig.Items[sampleItem].prop then
      print('Invalid sample item: ' .. sampleItem)
      print('Use an item with a prop (burger, fries, drink)')
      return
    end

    -- Get current slot position or start at center
    local currentSlot = GetTraySlot(slotIndex)
    local startPos = currentSlot or { x = 0, y = 0, z = 0.05, rx = 0, ry = 0, rz = 0 }

    slotTuneState.active = true
    slotTuneState.slotIndex = slotIndex
    slotTuneState.sampleItem = sampleItem
    slotTuneState.slotPos = {
      x = startPos.x,
      y = startPos.y,
      z = startPos.z,
      rx = startPos.rx,
      ry = startPos.ry,
      rz = startPos.rz,
    }

    -- Spawn preview
    refreshSlotTunePreview()

    if not slotTuneState.trayProp or not slotTuneState.itemProp then
      print('Failed to spawn preview props')
      cleanupSlotTunePreview()
      slotTuneState.active = false
      return
    end

    lib.notify({ description = 'Gizmo: W=move, R=rotate, G=cursor, Enter=done', type = 'info' })

    -- Record starting position and rotation
    local startWorldPos = GetEntityCoords(slotTuneState.itemProp)
    local startWorldRot = GetEntityRotation(slotTuneState.itemProp, 2)

    -- Use gizmo
    local result = exports.object_gizmo:useGizmo(slotTuneState.itemProp)

    if result and result.position then
      -- Convert to local coordinates
      local startLocal = GetOffsetFromEntityGivenWorldCoords(slotTuneState.trayProp, startWorldPos.x, startWorldPos.y,
        startWorldPos.z)
      local endLocal = GetOffsetFromEntityGivenWorldCoords(slotTuneState.trayProp, result.position.x, result.position.y,
        result.position.z)

      -- Calculate position delta and apply
      slotTuneState.slotPos.x = slotTuneState.slotPos.x + (endLocal.x - startLocal.x)
      slotTuneState.slotPos.y = slotTuneState.slotPos.y + (endLocal.y - startLocal.y)
      slotTuneState.slotPos.z = slotTuneState.slotPos.z + (endLocal.z - startLocal.z)

      -- Calculate rotation delta and apply
      if result.rotation then
        slotTuneState.slotPos.rx = slotTuneState.slotPos.rx + (result.rotation.x - startWorldRot.x)
        slotTuneState.slotPos.ry = slotTuneState.slotPos.ry + (result.rotation.y - startWorldRot.y)
        slotTuneState.slotPos.rz = slotTuneState.slotPos.rz + (result.rotation.z - startWorldRot.z)
      end
    end

    -- Print final values
    printSlotPosition(slotTuneState.slotIndex, slotTuneState.slotPos)

    -- Cleanup
    cleanupSlotTunePreview()
    slotTuneState.active = false

    lib.notify({ description = 'Slot tuning complete. Check console.', type = 'success' })
  end, false)

  -- Cleanup on resource stop
  AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    cleanupTunePreview()
    cleanupSlotTunePreview()
  end)
end
