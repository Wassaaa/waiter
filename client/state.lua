-- Shared state management
local sharedConfig = require 'config.shared'

State = {
  restaurantLoaded = false,
  PlayerJob = {}
}

function State.IsWaiter()
  return sharedConfig.JobName and State.PlayerJob.name == sharedConfig.JobName
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
