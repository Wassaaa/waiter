-- Furniture Spawning and Management
local sharedConfig = require 'config.shared'

-- Cleanup furniture and reset GlobalState
local function CleanupFurniture()
  if GlobalState.waiterFurniture then
    for _, item in ipairs(GlobalState.waiterFurniture) do
      local entity = NetworkGetEntityFromNetworkId(item.netid)
      if DoesEntityExist(entity) then
        DeleteEntity(entity)
      end
    end
  end

  if GlobalState.waiterGrill then
    local grill = NetworkGetEntityFromNetworkId(GlobalState.waiterGrill)
    if DoesEntityExist(grill) then
      DeleteEntity(grill)
    end
  end

  GlobalState.waiterFurniture = nil
  GlobalState.waiterGrill = nil
end

-- Setup Restaurant
---@param source number Player who triggered setup
lib.callback.register('waiter:server:setupRestaurant', function(source)
  -- Clean up any existing furniture first
  if GlobalState.waiterFurniture then
    lib.print.info('Cleaning up existing furniture before spawning new')
    CleanupFurniture()
    Wait(500) -- Give time for cleanup to replicate
  end

  local furniture = {}

  lib.print.info('Spawning Furniture Server-Side')

  -- Spawn all furniture pieces
  for _, item in ipairs(sharedConfig.Furniture) do
    local obj = CreateObject(item.hash, item.coords.x, item.coords.y, item.coords.z, true, true, false)

    lib.waitFor(function()
      if DoesEntityExist(obj) then return true end
    end, 'Failed to spawn furniture', 5000)

    if DoesEntityExist(obj) then
      SetEntityHeading(obj, item.coords.w)
      FreezeEntityPosition(obj, true)

      local netid = NetworkGetNetworkIdFromEntity(obj)
      table.insert(furniture, {
        netid = netid,
        type = item.type,
        coords = item.coords
      })
    end
  end

  -- Spawn kitchen grill
  local cooker = sharedConfig.KitchenGrill
  local grill = CreateObject(cooker.hash, cooker.coords.x, cooker.coords.y, cooker.coords.z, true, true, false)

  lib.waitFor(function()
    if DoesEntityExist(grill) then return true end
  end, 'Failed to spawn grill', 5000)

  if DoesEntityExist(grill) then
    SetEntityHeading(grill, cooker.coords.w)
    FreezeEntityPosition(grill, true)

    local grillNetId = NetworkGetNetworkIdFromEntity(grill)

    -- Store in GlobalState for all clients
    GlobalState.waiterFurniture = furniture
    GlobalState.waiterGrill = grillNetId

    lib.print.info(('Spawned %d furniture pieces and grill'):format(#furniture))
    return true
  end

  return false
end)

-- Cleanup Restaurant
RegisterNetEvent('waiter:server:cleanup', function()
  lib.print.info('Cleaning up restaurant server-side')
  CleanupFurniture()
end)

-- Cleanup on resource stop
AddEventHandler('onResourceStop', function(resourceName)
  if GetCurrentResourceName() ~= resourceName then return end
  CleanupFurniture()
end)
