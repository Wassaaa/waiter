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

---Get slot position on tray
---@param slotIndex number 1-based slot index
---@return table|nil slot {x, y, z} or nil if invalid
function GetTraySlot(slotIndex)
  return sharedConfig.Tray.slots[slotIndex]
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
    rx = offset.rx,
    ry = offset.ry,
    rz = offset.rz,
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
  local tuneState = {
    active = false,
    itemKey = nil,
    slotIndex = 1,
    offset = { x = 0, y = 0, z = 0, rx = 0, ry = 0, rz = 0 },
    trayProp = nil,
    itemProp = nil,
  }

  local function refreshTunePreview()
    if not tuneState.active then return end

    local ped = PlayerPedId()
    if not DoesEntityExist(ped) then return end

    -- Clean old preview
    if tuneState.itemProp and DoesEntityExist(tuneState.itemProp) then
      DeleteEntity(tuneState.itemProp)
    end
    if tuneState.trayProp and DoesEntityExist(tuneState.trayProp) then
      DeleteEntity(tuneState.trayProp)
    end

    -- Spawn tray
    tuneState.trayProp = SpawnTrayProp(ped)
    if not tuneState.trayProp then return end

    -- Get slot base position
    local slot = GetTraySlot(tuneState.slotIndex)
    if not slot then return end

    -- Create item with current tune offset
    local hash = GetItemPropHash(tuneState.itemKey)
    if not hash then return end

    lib.requestModel(hash)
    tuneState.itemProp = CreateObject(hash, 0, 0, 0, true, true, false)

    if not DoesEntityExist(tuneState.itemProp) then return end

    local off = tuneState.offset
    AttachEntityToEntity(
      tuneState.itemProp, tuneState.trayProp, 0,
      slot.x + off.x, slot.y + off.y, slot.z + off.z,
      off.rx, off.ry, off.rz,
      true, true, false, true, 1, true
    )
  end

  local function cleanupTunePreview()
    if tuneState.itemProp and DoesEntityExist(tuneState.itemProp) then
      DeleteEntity(tuneState.itemProp)
    end
    if tuneState.trayProp and DoesEntityExist(tuneState.trayProp) then
      DeleteEntity(tuneState.trayProp)
    end
    tuneState.itemProp = nil
    tuneState.trayProp = nil
  end

  local function printTuneOffset()
    local off = tuneState.offset
    print(('Item: %s | Slot: %d'):format(tuneState.itemKey, tuneState.slotIndex))
    print(('offset = { x = %.3f, y = %.3f, z = %.3f, rx = %.1f, ry = %.1f, rz = %.1f }'):format(
      off.x, off.y, off.z, off.rx, off.ry, off.rz
    ))
  end

  -- /tuneitem <itemKey> [slotIndex] - Start tuning an item's offset on tray
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

    refreshTunePreview()
    printTuneOffset()

    lib.notify({ description = 'Use /itemoff to adjust. /endtune when done.', type = 'info' })
  end, false)

  -- /itemoff <axis> <value> - Adjust item offset
  RegisterCommand('itemoff', function(_, args)
    if not tuneState.active then
      print('Start tuning first with /tuneitem')
      return
    end

    local axis = args[1]
    local value = tonumber(args[2])

    if not axis or not value then
      print('Usage: /itemoff <x|y|z|rx|ry|rz> <value>')
      return
    end

    axis = axis:lower()
    if not tuneState.offset[axis] then
      print('Invalid axis. Use: x, y, z, rx, ry, rz')
      return
    end

    tuneState.offset[axis] = tuneState.offset[axis] + value
    refreshTunePreview()
    printTuneOffset()
  end, false)

  -- /itemslot <slotIndex> - Change which slot to preview
  RegisterCommand('itemslot', function(_, args)
    if not tuneState.active then
      print('Start tuning first with /tuneitem')
      return
    end

    local slotIndex = tonumber(args[1])
    if not slotIndex or slotIndex < 1 or slotIndex > #sharedConfig.Tray.slots then
      print('Invalid slot. Available: 1-' .. #sharedConfig.Tray.slots)
      return
    end

    tuneState.slotIndex = slotIndex
    refreshTunePreview()
    printTuneOffset()
  end, false)

  -- /endtune - End tuning and print final values
  RegisterCommand('endtune', function()
    if not tuneState.active then return end

    print('========== FINAL OFFSET ==========')
    printTuneOffset()
    print('Copy this to config/shared.lua:')
    local off = tuneState.offset
    print(('%s = {'):format(tuneState.itemKey))
    print(('  -- ... other fields ...'))
    print(('  offset = { x = %.3f, y = %.3f, z = %.3f, rx = %.1f, ry = %.1f, rz = %.1f },'):format(
      off.x, off.y, off.z, off.rx, off.ry, off.rz
    ))
    print('},')
    print('==================================')

    cleanupTunePreview()
    tuneState.active = false
    tuneState.itemKey = nil

    lib.notify({ description = 'Tuning ended. Check console for values.', type = 'success' })
  end, false)

  -- Cleanup on resource stop
  AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    cleanupTunePreview()
  end)
end
