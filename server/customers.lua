-- Customer Management - Server Side
local clientConfig = require 'config.client'
local sharedConfig = require 'config.shared'

-- Track active customers
local customers = {}

---Get a random order for customer
---@return table order Array of item names
local function generateOrder()
  local itemKeys = {}
  for k, _ in pairs(sharedConfig.Items) do
    table.insert(itemKeys, k)
  end

  local orderSize = math.random(1, 3)
  local order = {}
  for i = 1, orderSize do
    table.insert(order, itemKeys[math.random(1, #itemKeys)])
  end
  return order
end

---Spawn a single customer
local function SpawnCustomer()
  -- Find available seat
  local availableSeats = {}
  if not GlobalState.waiterFurniture then return end

  for i, item in ipairs(GlobalState.waiterFurniture) do
    if item.type == 'chair' then
      local isOccupied = false
      for _, customer in pairs(customers) do
        if customer.seatId == i then
          isOccupied = true
          break
        end
      end
      if not isOccupied then
        table.insert(availableSeats, { id = i, coords = item.coords })
      end
    end
  end

  if #availableSeats == 0 then
    lib.print.info('No available seats for customer')
    return
  end

  local seat = availableSeats[math.random(1, #availableSeats)]
  local model = clientConfig.Models[math.random(1, #clientConfig.Models)]
  local entrance = clientConfig.EntranceCoords

  -- Spawn ped on server
  local ped = CreatePed(4, joaat(model), entrance.x, entrance.y, entrance.z, entrance.w, true, true)

  lib.waitFor(function()
    if DoesEntityExist(ped) then return true end
  end, 'Failed to spawn customer', 5000)

  if not DoesEntityExist(ped) then
    lib.print.error('Customer ped failed to spawn')
    return
  end

  local netid = NetworkGetNetworkIdFromEntity(ped)
  local customerId = #customers + 1

  -- Create customer data
  local customerData = {
    id = customerId,
    netid = netid,
    seatId = seat.id,
    seatCoords = seat.coords,
    status = 'walking_in',
    order = generateOrder(),
    patienceTimer = GetGameTimer()
  }

  customers[customerId] = customerData

  -- Set entity statebag for this specific customer
  Entity(ped).state:set('waiterCustomer', customerData, true)

  lib.print.info(('Customer %d spawned at seat %d'):format(customerId, seat.id))

  -- Start customer logic (patience monitoring only)
  CreateThread(function()
    -- Patience loop
    while customers[customerId] do
      local customer = customers[customerId]

      if customer.status == 'waiting_order' then
        if (GetGameTimer() - customer.patienceTimer) > clientConfig.PatienceOrder then
          customer.status = 'leaving_angry'
          customer.leavingTimer = GetGameTimer() -- Track when they started leaving
          Entity(ped).state:set('waiterCustomer', customer, true)
        end
      elseif customer.status == 'waiting_food' then
        if (GetGameTimer() - customer.patienceTimer) > clientConfig.PatienceFood then
          customer.status = 'leaving_angry'
          customer.leavingTimer = GetGameTimer()
          Entity(ped).state:set('waiterCustomer', customer, true)
        end
      elseif customer.status == 'eating' then
        Wait(clientConfig.EatTime)
        customer.status = 'leaving_happy'
        customer.leavingTimer = GetGameTimer()
        Entity(ped).state:set('waiterCustomer', customer, true)
      elseif customer.status == 'leaving_angry' or customer.status == 'leaving_happy' then
        -- Check if leaving timeout exceeded
        if customer.leavingTimer and (GetGameTimer() - customer.leavingTimer) > clientConfig.WalkoutTimeout then
          if DoesEntityExist(ped) then DeleteEntity(ped) end
          customers[customerId] = nil
          lib.print.info(('Customer %d cleanup: walkout timeout'):format(customerId))
          break
        end
      end

      Wait(1000)
    end
  end)
end

-- Events
RegisterNetEvent('waiter:server:customerArrived', function(customerId)
  local customer = customers[customerId]
  if not customer or customer.status ~= 'walking_in' then return end

  local ped = NetworkGetEntityFromNetworkId(customer.netid)
  if not DoesEntityExist(ped) then return end

  -- Customer arrived, sit them down
  customer.status = 'sitting'
  Entity(ped).state:set('waiterCustomer', customer, true)

  -- Wait then change to waiting_order
  CreateThread(function()
    Wait(clientConfig.SitDelay)
    if customers[customerId] and customers[customerId].status == 'sitting' then
      customer.status = 'waiting_order'
      customer.patienceTimer = GetGameTimer()
      Entity(ped).state:set('waiterCustomer', customer, true)
    end
  end)

  lib.print.info(('Customer %d arrived at seat'):format(customerId))
end)

RegisterNetEvent('waiter:server:customerExited', function(customerId)
  local customer = customers[customerId]
  if not customer then return end

  local ped = NetworkGetEntityFromNetworkId(customer.netid)
  if DoesEntityExist(ped) then
    DeleteEntity(ped)
  end
  customers[customerId] = nil
  lib.print.info(('Customer %d exited and cleaned up'):format(customerId))
end)

RegisterNetEvent('waiter:server:takeOrder', function(customerId)
  local customer = customers[customerId]
  if not customer or customer.status ~= 'waiting_order' then return end

  local ped = NetworkGetEntityFromNetworkId(customer.netid)
  if not DoesEntityExist(ped) then return end

  customer.status = 'waiting_food'
  customer.patienceTimer = GetGameTimer()
  Entity(ped).state:set('waiterCustomer', customer, true)

  lib.print.info(('Order taken for customer %d'):format(customerId))
end)

RegisterNetEvent('waiter:server:deliverFood', function(customerId, itemsDelivered)
  local customer = customers[customerId]
  if not customer then return end

  local ped = NetworkGetEntityFromNetworkId(customer.netid)
  if not DoesEntityExist(ped) then return end

  -- If order is complete
  if #customer.order == 0 then
    customer.status = 'eating'
    Entity(ped).state:set('waiterCustomer', customer, true)
    lib.print.info(('Customer %d is eating'):format(customerId))
  else
    -- Still waiting for more items
    customer.patienceTimer = GetGameTimer()
    Entity(ped).state:set('waiterCustomer', customer, true)
  end
end)

RegisterNetEvent('waiter:server:updateCustomerOrder', function(customerId, newOrder)
  local customer = customers[customerId]
  if not customer then return end

  customer.order = newOrder
  local ped = NetworkGetEntityFromNetworkId(customer.netid)
  if DoesEntityExist(ped) then
    Entity(ped).state:set('waiterCustomer', customer, true)
  end
end)

-- Callback to start spawning customers
lib.callback.register('waiter:server:startCustomerSpawning', function(source)
  CreateThread(function()
    Wait(2000)
    while GlobalState.waiterFurniture do
      SpawnCustomer()
      Wait(clientConfig.SpawnInterval)
    end
  end)
  return true
end)

-- Cleanup
RegisterNetEvent('waiter:server:cleanupCustomers', function()
  for _, customer in pairs(customers) do
    local ped = NetworkGetEntityFromNetworkId(customer.netid)
    if DoesEntityExist(ped) then
      DeleteEntity(ped)
    end
  end
  customers = {}
  lib.print.info('All customers cleaned up')
end)

-- Cleanup on resource stop
AddEventHandler('onResourceStop', function(resourceName)
  if GetCurrentResourceName() ~= resourceName then return end
  for _, customer in pairs(customers) do
    local ped = NetworkGetEntityFromNetworkId(customer.netid)
    if DoesEntityExist(ped) then
      DeleteEntity(ped)
    end
  end
end)
