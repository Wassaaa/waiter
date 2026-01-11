local Tray = require 'client.lib.tray'
local clientConfig = require 'config.client'

-- Store tray props for each player {[serverId] = TrayInstance}
---@type table<number, Tray>
local playerTrays = {}

---Clean up tray props for a player
local function cleanupPlayerTray(playerId, clearAnim)
  if clearAnim == nil then clearAnim = true end

  local trayInstance = playerTrays[playerId]
  if trayInstance then
    trayInstance:Destroy()
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
  lib.print.debug('updatePlayerTray', playerId, 'State:', json.encode(trayState))

  -- Cleanup previous
  cleanupPlayerTray(playerId, trayState == nil or #trayState == 0)

  if not trayState or #trayState == 0 then return end

  local playerIdx = GetPlayerFromServerId(playerId)
  if playerIdx == -1 then
    lib.print.debug('Player not found (Out of scope)', playerId)
    return
  end
  local ped = GetPlayerPed(playerIdx)
  if not DoesEntityExist(ped) then
    lib.print.debug('Ped not found for player index by server id', playerId, playerIdx)
    return
  end

  -- Play Anim
  Utils.PlayAnimUpper(ped, clientConfig.Anims.Tray.dict, clientConfig.Anims.Tray.anim, true)

  -- Spawn Visual Tray via Class
  local trayInstance = Tray.CreateAttached(ped)
  if not trayInstance then return end

  -- Spawn Items via Class
  trayInstance:AddStateItems(trayState)

  playerTrays[playerId] = trayInstance

  -- Watch for ped deletion & Enforce Animation
  CreateThread(function()
    local animDict = clientConfig.Anims.Tray.dict
    local animName = clientConfig.Anims.Tray.anim

    while playerTrays[playerId] == trayInstance do
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
