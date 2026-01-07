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
    joaat('prop_table_01'),
  }

  local centerCoord = vector3(config.EntranceCoords.x, config.EntranceCoords.y, config.EntranceCoords.z)
  local deletedCount = 0

  -- Get ALL objects in the world
  local allObjects = GetGamePool('CObject')

  for _, obj in ipairs(allObjects) do
    local model = GetEntityModel(obj)
    local coords = GetEntityCoords(obj)
    local dist = #(coords - centerCoord)

    -- Check if this object is one of our target hashes and within radius
    local isTargetHash = false
    for _, hash in ipairs(propsToDelete) do
      if model == hash then
        isTargetHash = true
        break
      end
    end

    if isTargetHash and dist <= config.CleanupRadius then
      -- Check if this is one of OUR spawned entities
      local isOurFurniture = false
      for _, spawnedProp in ipairs(State.spawnedProps) do
        if obj == spawnedProp then
          isOurFurniture = true
          break
        end
      end

      if not isOurFurniture then
        SetEntityAsMissionEntity(obj, true, true)
        DeleteObject(obj)
        DeleteEntity(obj)
        deletedCount = deletedCount + 1
      end
    end
  end

  if deletedCount > 0 then
    lib.print.info(('Cleaned up %d world props'):format(deletedCount))
  end
end

function SetupRestaurant()
  -- Check if restaurant is already set up by another player
  if GlobalState.waiterFurniture then
    lib.notify({ type = 'info', description = 'Restaurant is already set up' })

    -- Get existing furniture from GlobalState and populate our tracking
    local furniture = GlobalState.waiterFurniture
    for _, item in ipairs(furniture) do
      local obj = NetworkGetEntityFromNetworkId(item.netid)
      if DoesEntityExist(obj) then
        table.insert(State.spawnedProps, obj)

        if item.type == 'chair' then
          local finalCoords = GetEntityCoords(obj)
          table.insert(State.validSeats, {
            entity = obj,
            coords = vector4(finalCoords.x, finalCoords.y, finalCoords.z, item.coords.w),
            isOccupied = false,
            id = #State.validSeats + 1
          })
        end
      end
    end

    -- Clean up world props now that we know what's ours
    DeleteWorldProps()

    SetupKitchen()
    State.isRestaurantOpen = true
    lib.print.info(('Restaurant already open! Seats: %d'):format(#State.validSeats))
    return
  end

  -- Fresh setup
  CleanupScene()

  lib.print.info('Requesting server to spawn furniture')
  local success = lib.callback.await('waiter:server:setupRestaurant', false)

  if not success then
    lib.notify({ type = 'error', description = 'Failed to setup restaurant' })
    return
  end

  -- Wait for GlobalState to be populated by server
  local furniture = lib.waitFor(function()
    if GlobalState.waiterFurniture then return GlobalState.waiterFurniture end
  end, 'Furniture not spawned by server', 5000)

  if not furniture then
    lib.print.error('Furniture GlobalState not set')
    return
  end

  -- Get furniture entities and populate our tracking
  lib.print.info(('Processing %d furniture pieces'):format(#furniture))
  for _, item in ipairs(furniture) do
    local obj = NetworkGetEntityFromNetworkId(item.netid)

    if DoesEntityExist(obj) then
      table.insert(State.spawnedProps, obj)

      if item.type == 'chair' then
        local finalCoords = GetEntityCoords(obj)
        table.insert(State.validSeats, {
          entity = obj,
          coords = vector4(finalCoords.x, finalCoords.y, finalCoords.z, item.coords.w),
          isOccupied = false,
          id = #State.validSeats + 1
        })
      end
    end
  end

  -- Clean up world props now that we know what's ours
  DeleteWorldProps()

  SetupKitchen()
  State.isRestaurantOpen = true
  lib.print.info(('Restaurant Open! Seats: %d'):format(#State.validSeats))

  -- Thread: Keep world props deleted
  CreateThread(function()
    while State.isRestaurantOpen do
      DeleteWorldProps()
      Wait(2000)
    end
  end)

  -- Thread: Spawn customers
  CreateThread(function()
    Wait(2000)
    while State.isRestaurantOpen do
      if State.isRestaurantOpen then SpawnSingleCustomer() end
      Wait(config.SpawnInterval)
    end
  end)
end
