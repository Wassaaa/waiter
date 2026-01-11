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

function GetMyTray()
  return LocalPlayer.state.waiterTray or {}
end

function MatchTrayWithOrder(tray, order)
  local matchedItems = {}
  local itemsDelivered = 0
  -- Shallow copy to track consumption without modifying source immediately
  local availableItems = { table.unpack(tray) }

  for _, orderKey in ipairs(order) do
    for i, item in ipairs(availableItems) do
      if item.key == orderKey then
        table.insert(matchedItems, item)
        itemsDelivered = itemsDelivered + 1
        table.remove(availableItems, i)
        break
      end
    end
  end

  return matchedItems, itemsDelivered
end
