-- Server-side Payment Logic
lib.versionCheck('Wassaaa/waiter')
lib.print.info('Server Started')

local config = require 'config.shared'

---@param source number Player source
---@return boolean canWork Whether player can work
---@return string? reason Reason if they can't work
local function canPlayerWork(source)
  if not config.JobName then
    return true -- No job requirement
  end

  local player = exports.qbx_core:GetPlayer(source)
  if not player then
    return false, 'Player not found'
  end

  -- Check if player has the correct job
  if player.PlayerData.job.name ~= config.JobName then
    return false, 'You must have the waiter job to earn money'
  end

  -- Check if player is on duty (if required)
  if config.RequireOnDuty and not player.PlayerData.job.onduty then
    return false, 'You must be on duty to earn money'
  end

  return true
end

-- Payment Event
---@param itemsDelivered number Number of items delivered to customer
RegisterNetEvent('waiter:pay', function(itemsDelivered)
  local src = source --[[@as number]]

  if not itemsDelivered or itemsDelivered < 1 then return end

  -- Security: Validate player can work
  local canWork, reason = canPlayerWork(src)
  if not canWork then
    exports.qbx_core:Notify(src, reason, 'error')
    return
  end

  local player = exports.qbx_core:GetPlayer(src)
  if not player then return end

  local amount = itemsDelivered * config.PayPerItem

  -- Add money to player
  local success = player.Functions.AddMoney(config.PaymentType, amount, 'waiter-job-payment')

  if success then
    exports.qbx_core:Notify(src, ('Earned $%s for %s items!'):format(amount, itemsDelivered), 'success')
  else
    exports.qbx_core:Notify(src, 'Payment failed!', 'error')
  end
end)

lib.callback.register('waiter:canWork', function(source)
  return canPlayerWork(source)
end)

-- Furniture Spawning
---@param source number Player who triggered setup
lib.callback.register('waiter:server:setupRestaurant', function(source)
  local clientConfig = require 'config.client'
  local furniture = {}

  lib.print.info('Spawning Furniture Server-Side')

  -- Spawn all furniture pieces
  for _, item in ipairs(clientConfig.Furniture) do
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
  local cooker = clientConfig.KitchenGrill
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

  -- Delete furniture
  if GlobalState.waiterFurniture then
    for _, item in ipairs(GlobalState.waiterFurniture) do
      local entity = NetworkGetEntityFromNetworkId(item.netid)
      if DoesEntityExist(entity) then
        DeleteEntity(entity)
      end
    end
  end

  -- Delete grill
  if GlobalState.waiterGrill then
    local grill = NetworkGetEntityFromNetworkId(GlobalState.waiterGrill)
    if DoesEntityExist(grill) then
      DeleteEntity(grill)
    end
  end

  GlobalState.waiterFurniture = nil
  GlobalState.waiterGrill = nil
end)

-- Cleanup on resource stop
AddEventHandler('onResourceStop', function(resourceName)
  if GetCurrentResourceName() ~= resourceName then return end

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
end)
