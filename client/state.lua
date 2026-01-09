-- Shared state management
State = {
  validSeats = {},
  customers = {},
  kitchenGrill = nil,
  isRestaurantOpen = false
}

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

  -- Request server to cleanup furniture and customers
  -- Server handles ped deletion, which auto-replicates to clients
  if State.isRestaurantOpen then
    TriggerServerEvent('waiter:server:cleanup')
    TriggerServerEvent('waiter:server:cleanupCustomers')
  end

  -- Reset Logic
  State.validSeats = {}
  State.customers = {}
  State.isRestaurantOpen = false
  State.kitchenGrill = nil
end
