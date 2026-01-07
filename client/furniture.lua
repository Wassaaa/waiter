-- Furniture and Restaurant Setup
local config = require 'config.client'
local sharedConfig = require 'config.shared'

function SetupKitchen()
  -- Wait for server to spawn grill
  if not GlobalState.waiterGrill then
    lib.print.error('Grill not spawned by server')
    return
  end

  local grill = NetworkGetEntityFromNetworkId(GlobalState.waiterGrill)
  if not DoesEntityExist(grill) then
    lib.print.error('Grill entity does not exist')
    return
  end

  local options = {}

  -- Generate Add Options
  for k, v in pairs(sharedConfig.Items) do
    table.insert(options, {
      name = 'add_' .. k,
      icon = 'fa-solid fa-plus',
      label = 'Pick up ' .. v.label,
      distance = 2.0,
      onSelect = function() ModifyHand('add', k) end
    })
  end

  -- Clear Tray Option
  table.insert(options, {
    name = 'clear_tray',
    icon = 'fa-solid fa-trash',
    label = 'Clear Tray',
    distance = 2.0,
    onSelect = function() ModifyHand('clear') end
  })

  exports.ox_target:addLocalEntity(grill, options)
  State.kitchenGrill = grill
end

function DeleteWorldProps()
  local propsToDelete = {
    joaat('prop_chair_01a'),
    joaat('prop_table_01')
  }

  -- Only delete world props that are NOT at our furniture coordinates
  local radiusCheck = 100.0 -- Check in a radius around restaurant
  local centerCoord = config.EntranceCoords

  for _, hash in ipairs(propsToDelete) do
    local obj = GetClosestObjectOfType(centerCoord.x, centerCoord.y, centerCoord.z, radiusCheck, hash, false, false,
      false)

    while DoesEntityExist(obj) do
      local objCoords = GetEntityCoords(obj)
      local isOurFurniture = false

      -- Check if this object is at one of our furniture spawn points
      for _, item in ipairs(config.Furniture) do
        if #(objCoords - vector3(item.coords.x, item.coords.y, item.coords.z)) < 0.5 then
          isOurFurniture = true
          break
        end
      end

      if not isOurFurniture then
        SetEntityAsMissionEntity(obj, true, true)
        DeleteObject(obj)
      end

      -- Find next closest (skip the one we just processed)
      obj = GetClosestObjectOfType(centerCoord.x, centerCoord.y, centerCoord.z, radiusCheck, hash, false, false, false)
      if isOurFurniture then break end -- Don't keep looping if we found our furniture
    end
  end
end

function SetupRestaurant()
  -- Check if restaurant is already set up by another player
  if GlobalState.waiterFurniture then
    lib.notify({ type = 'info', description = 'Restaurant is already set up' })

    -- Just get the existing furniture from GlobalState
    local furniture = GlobalState.waiterFurniture
    for _, item in ipairs(furniture) do
      local obj = NetworkGetEntityFromNetworkId(item.netid)
      if DoesEntityExist(obj) then
        table.insert(State.spawnedProps, obj)
        if item.type == 'chair' then
          local finalCoords = GetEntityCoords(obj)
          local newId = #State.validSeats + 1
          table.insert(State.validSeats, {
            entity = obj,
            coords = vector4(finalCoords.x, finalCoords.y, finalCoords.z, item.coords.w),
            isOccupied = false,
            id = newId
          })
        end
      end
    end

    SetupKitchen()
    State.isRestaurantOpen = true
    lib.print.info(('Restaurant already open! Seats: %d'):format(#State.validSeats))

    -- Start customer spawning
    CreateThread(function()
      Wait(2000)
      if State.isRestaurantOpen then SpawnSingleCustomer() end

      while State.isRestaurantOpen do
        Wait(config.SpawnInterval)
        if State.isRestaurantOpen then SpawnSingleCustomer() end
      end
    end)

    return
  end

  CleanupScene()

  -- Call server to spawn furniture
  lib.print.info('Requesting server to spawn furniture')
  local success = lib.callback.await('waiter:server:setupRestaurant', false)

  if not success then
    lib.notify({ type = 'error', description = 'Failed to setup restaurant' })
    return
  end

  -- Wait for GlobalState to be populated
  local furniture = lib.waitFor(function()
    if GlobalState.waiterFurniture then return GlobalState.waiterFurniture end
  end, 'Furniture not spawned by server', 5000)

  if not furniture then
    lib.print.error('Furniture GlobalState not set')
    return
  end

  DeleteWorldProps()

  -- Get furniture entities from server
  lib.print.info(('Processing %d furniture pieces'):format(#furniture))

  for _, item in ipairs(furniture) do
    local obj = NetworkGetEntityFromNetworkId(item.netid)

    if DoesEntityExist(obj) then
      table.insert(State.spawnedProps, obj)

      if item.type == 'chair' then
        local finalCoords = GetEntityCoords(obj)
        local newId = #State.validSeats + 1
        table.insert(State.validSeats, {
          entity = obj,
          coords = vector4(finalCoords.x, finalCoords.y, finalCoords.z, item.coords.w),
          isOccupied = false,
          id = newId
        })
      end
    end
  end

  SetupKitchen()
  State.isRestaurantOpen = true
  lib.print.info(('Restaurant Open! Seats: %d'):format(#State.validSeats))

  -- Thread: Keep world props deleted
  CreateThread(function()
    while State.isRestaurantOpen do
      DeleteWorldProps()
      Wait(5000)
    end
  end)

  -- Thread: Spawn customers
  CreateThread(function()
    Wait(2000)
    if State.isRestaurantOpen then SpawnSingleCustomer() end

    while State.isRestaurantOpen do
      Wait(config.SpawnInterval)
      if State.isRestaurantOpen then SpawnSingleCustomer() end
    end
  end)
end
