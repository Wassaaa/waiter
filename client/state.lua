-- Shared state management
local sharedConfig = require 'config.shared'

State = {
  restaurantLoaded = false,
  PlayerJob = {}
}

function State.IsWaiter()
  return sharedConfig.JobName and State.PlayerJob.name == sharedConfig.JobName
end

-- Utility Functions
function SafeDelete(entity)
  if DoesEntityExist(entity) then DeleteEntity(entity) end
end

function PlayAnimUpper(ped, dict, anim, loop)
  if not DoesEntityExist(ped) then return end
  local flag = 48 -- Upper body only
  local duration = 3000
  if loop then
    flag = 49     -- 48 + 1 = Upper body + Loop
    duration = -1 -- Indefinite when looping
  end
  lib.requestAnimDict(dict)
  TaskPlayAnim(ped, dict, anim, 8.0, -8.0, duration, flag, 0, false, false, false)
end

function CleanupScene()
  -- Clear player's tray via server
  TriggerServerEvent('waiter:server:modifyTray', 'clear')

  -- Remove ox_target options from kitchen props
  if RemoveKitchenTargets then RemoveKitchenTargets() end

  -- Restore world props
  if ManageModelHides then ManageModelHides(false) end

  -- Reset Logic
  State.restaurantLoaded = false
end
