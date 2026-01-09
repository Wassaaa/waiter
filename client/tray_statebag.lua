-- Tray Statebag Handler - Watches for tray changes on ALL players and renders props locally
local clientConfig = require 'config.client'
local sharedConfig = require 'config.shared'

-- Store tray props for each player {[serverId] = {tray = entity, items = {entities}}}
local playerTrays = {}

---Clean up tray props for a player
---@param playerId number Server ID of player
local function cleanupPlayerTray(playerId)
  if not playerTrays[playerId] then return end

  local trayData = playerTrays[playerId]
  if trayData.tray and DoesEntityExist(trayData.tray) then
    DeleteEntity(trayData.tray)
  end

  for _, prop in ipairs(trayData.items or {}) do
    if DoesEntityExist(prop) then
      DeleteEntity(prop)
    end
  end

  playerTrays[playerId] = nil
end

---Update tray visuals for a player
---@param playerId number Server ID of player
---@param trayItems table Array of item names
local function updatePlayerTray(playerId, trayItems)
  -- Clean up old props first
  cleanupPlayerTray(playerId)

  -- If empty tray, just clear animation
  if not trayItems or #trayItems == 0 then
    local ped = GetPlayerPed(GetPlayerFromServerId(playerId))
    if DoesEntityExist(ped) then
      ClearPedTasks(ped)
    end
    return
  end

  -- Get the player's ped
  local ped = GetPlayerPed(GetPlayerFromServerId(playerId))
  if not DoesEntityExist(ped) then return end

  -- Play animation
  PlayAnimUpper(ped, clientConfig.Anims.Tray.dict, clientConfig.Anims.Tray.anim, true)

  -- Spawn tray prop
  local trayHash = joaat("prop_food_tray_01")
  lib.requestModel(trayHash)
  local trayProp = CreateObject(trayHash, 0, 0, 0, true, true, false)

  local boneIndex = GetPedBoneIndex(ped, 57005)
  local x, y, z = 0.1, 0.05, -0.1
  local rx, ry, rz = 190.0, 300.0, 50.0

  AttachEntityToEntity(trayProp, ped, boneIndex, x, y, z, rx, ry, rz, true, true, false, true, 1, true)

  -- Spawn item props
  local offsets = {
    vector3(0.0, 0.12, 0.05),    -- Center Front
    vector3(-0.12, -0.08, 0.05), -- Left Back
    vector3(0.12, -0.08, 0.05)   -- Right Back
  }

  local itemProps = {}
  for i, itemName in ipairs(trayItems) do
    if sharedConfig.Items[itemName] then
      local propName = sharedConfig.Items[itemName].prop
      local hash = joaat(propName)
      lib.requestModel(hash)

      local itemObj = CreateObject(hash, 0, 0, 0, true, true, false)
      local off = offsets[i] or vector3(0, 0, 0)

      AttachEntityToEntity(itemObj, trayProp, 0, off.x, off.y, off.z, 0.0, 0.0, 0.0, true, true, false, true, 1, true)
      table.insert(itemProps, itemObj)
    end
  end

  -- Store props
  playerTrays[playerId] = {
    tray = trayProp,
    items = itemProps
  }

  -- Monitor this specific tray for player existence
  CreateThread(function()
    while playerTrays[playerId] and playerTrays[playerId].tray == trayProp do
      if not DoesEntityExist(ped) then
        cleanupPlayerTray(playerId)
        break
      end
      Wait(60000)
    end
  end)
end

-- Watch for tray changes on ALL players
AddStateBagChangeHandler('waiterTray', "", function(bagName, _, value, _, replicated)
  -- bagName format: "player:123"
  local playerId = tonumber((bagName:gsub('player:', '')))
  if not playerId then return end

  lib.print.info(('Tray statebag changed for player %s'):format(playerId))

  -- Update visuals
  updatePlayerTray(playerId, value)
end)

-- Cleanup on resource stop
AddEventHandler('onResourceStop', function(resourceName)
  if GetCurrentResourceName() ~= resourceName then return end

  for playerId, _ in pairs(playerTrays) do
    cleanupPlayerTray(playerId)
  end
end)
