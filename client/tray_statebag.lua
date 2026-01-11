-- Tray Statebag Handler - Watches for tray changes on ALL players and renders props locally
local clientConfig = require 'config.client'
local sharedConfig = require 'config.shared'

-- Store tray props for each player {[serverId] = {tray = entity, items = {entities}}}
local playerTrays = {}

---Clean up tray props for a player (optionally clear animation)
---@param playerId number Server ID of player
---@param clearAnim boolean? Whether to also clear the animation (default: true)
local function cleanupPlayerTray(playerId, clearAnim)
  if clearAnim == nil then clearAnim = true end

  if not playerTrays[playerId] then
    -- No tracked props, but might still need to clear animation
    if clearAnim then
      local ped = GetPlayerPed(GetPlayerFromServerId(playerId))
      if DoesEntityExist(ped) then
        ClearPedTasks(ped)
      end
    end
    return
  end

  local trayData = playerTrays[playerId]
  if trayData.tray and DoesEntityExist(trayData.tray) then
    DeleteEntity(trayData.tray)
  end

  for _, prop in ipairs(trayData.items or {}) do
    if DoesEntityExist(prop) then
      DeleteEntity(prop)
    end
  end

  -- Clear the tray animation only if requested
  if clearAnim then
    local ped = GetPlayerPed(GetPlayerFromServerId(playerId))
    if DoesEntityExist(ped) then
      ClearPedTasks(ped)
    end
  end

  playerTrays[playerId] = nil
end

---Update tray visuals for a player
---@param playerId number Server ID of player
---@param trayItems table Array of item names
local function updatePlayerTray(playerId, trayItems)
  local hasItems = trayItems and #trayItems > 0

  -- Clean up old props, only clear animation if tray will be empty
  cleanupPlayerTray(playerId, not hasItems)

  -- If empty tray, nothing more to do
  if not hasItems then return end

  -- Get the player's ped
  local ped = GetPlayerPed(GetPlayerFromServerId(playerId))
  if not DoesEntityExist(ped) then return end

  -- Play animation
  Utils.PlayAnimUpper(ped, clientConfig.Anims.Tray.dict, clientConfig.Anims.Tray.anim, true)

  -- Spawn tray using helper
  local trayProp = SpawnTrayProp(ped)
  if not trayProp then return end

  local itemProps = {}
  local maxSlots = GetAvailableTraySlots()

  for slotIndex, itemKey in ipairs(trayItems) do
    if slotIndex > maxSlots then break end

    local itemProp = SpawnItemOnTray(trayProp, slotIndex, itemKey)
    if itemProp then
      table.insert(itemProps, itemProp)
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
      Wait(10000)
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
