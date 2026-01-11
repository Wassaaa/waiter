local DragDrop = require 'client.lib.dragdrop'
local Tray = require 'client.lib.tray'
local sharedConfig = require 'config.shared'
local clientConfig = require 'config.client'

-- Store tray props for each player {[serverId] = {tray = entity, items = {entities}}}
local playerTrays = {}

---Clean up tray props for a player
local function cleanupPlayerTray(playerId, clearAnim)
  if clearAnim == nil then clearAnim = true end

  local data = playerTrays[playerId]
  if data then
    if DoesEntityExist(data.tray) then DeleteEntity(data.tray) end
    for _, prop in ipairs(data.items or {}) do
      if DoesEntityExist(prop) then DeleteEntity(prop) end
    end
    playerTrays[playerId] = nil
  end

  if clearAnim then
    local ped = GetPlayerPed(GetPlayerFromServerId(playerId))
    if DoesEntityExist(ped) then
      ClearPedTasks(ped)
    end
  end
end

---Update tray visuals from Statebag
local function updatePlayerTray(playerId, trayState)
  lib.print.info('DEBUG: updatePlayerTray', playerId, 'State:', json.encode(trayState))
  -- Cleanup previous
  cleanupPlayerTray(playerId, trayState == nil or #trayState == 0)

  if not trayState or #trayState == 0 then return end

  local playerIdx = GetPlayerFromServerId(playerId)
  if playerIdx == -1 then
    lib.print.info('DEBUG: Player not found (Out of scope)', playerId)
    return
  end
  local ped = GetPlayerPed(playerIdx)
  if not DoesEntityExist(ped) then
    lib.print.error('DEBUG: Ped not found for player index by server id', playerId, playerIdx)
    return
  end

  -- Play Anim
  Utils.PlayAnimUpper(ped, clientConfig.Anims.Tray.dict, clientConfig.Anims.Tray.anim, true)

  -- Spawn Visual Tray
  local trayModel = joaat(sharedConfig.Tray.prop)
  lib.requestModel(trayModel)
  local trayEntity = CreateObject(trayModel, 0, 0, 0, false, false, false)
  SetEntityCollision(trayEntity, false, false)
  lib.print.info('DEBUG: Tray Entity Created', trayEntity, 'Model:', trayModel)

  -- Attach to Player (using Shared Config)
  local config = sharedConfig.Tray
  local off = config.offset
  local rot = config.rotation

  AttachEntityToEntity(trayEntity, ped, GetPedBoneIndex(ped, config.bone),
    off.x, off.y, off.z,
    rot.x, rot.y, rot.z,
    true, true, false, true, 1, true
  )

  local itemProps = {}

  -- Spawn Items
  for _, itemData in ipairs(trayState) do
    local key = itemData.key
    local action = sharedConfig.Actions[key]
    if action and action.prop then
      local model = joaat(action.prop)
      lib.requestModel(model)
      local itemEntity = CreateObject(model, 0, 0, 0, false, false, false)
      SetEntityCollision(itemEntity, false, false)
      lib.print.info('DEBUG: Item Spawned', key, itemEntity)

      -- Attach using synced offsets
      AttachEntityToEntity(itemEntity, trayEntity, 0,
        itemData.x, itemData.y, itemData.z,
        itemData.rx, itemData.ry, itemData.rz,
        false, false, false, false, 0, true
      )
      table.insert(itemProps, itemEntity)
    else
      lib.print.error('DEBUG: Missing action or prop for key', key)
    end
  end

  playerTrays[playerId] = {
    tray = trayEntity,
    items = itemProps
  }

  -- Watch for ped deletion & Enforce Animation
  CreateThread(function()
    local animDict = clientConfig.Anims.Tray.dict
    local animName = clientConfig.Anims.Tray.anim

    while playerTrays[playerId] and playerTrays[playerId].tray == trayEntity do
      if not DoesEntityExist(ped) then
        cleanupPlayerTray(playerId)
        break
      end

      -- Enforce Animation if not playing (recover from collisions)
      if not IsEntityPlayingAnim(ped, animDict, animName, 3) then
        if not IsPedRagdoll(ped) and not IsPedFalling(ped) and not IsEntityDead(ped) then
          Utils.PlayAnimUpper(ped, animDict, animName, true)
        end
      end

      Wait(500)
    end
  end)
end

-- Watch for Statebag changes
AddStateBagChangeHandler('waiterTray', nil, function(bagName, key, value, _reserved, replicated)
  local playerIdx = GetPlayerFromStateBagName(bagName)
  if playerIdx == 0 then return end

  -- Get Server ID (for our storage keys)
  local playerId = GetPlayerServerId(playerIdx)

  updatePlayerTray(playerId, value)
end)

-- Cleanup on stop
AddEventHandler('onResourceStop', function(resource)
  if resource == GetCurrentResourceName() then
    for playerId, _ in pairs(playerTrays) do
      cleanupPlayerTray(playerId)
    end
  end
end)
