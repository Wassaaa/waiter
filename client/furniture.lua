-- Furniture and Restaurant Setup
local clientConfig = require 'config.client'
local sharedConfig = require 'config.shared'

function SetupKitchen()
  -- Wait for server to spawn grill
  if not GlobalState.waiterGrill then
    lib.print.error('Grill not spawned by server')
    return
  end

  -- Wait for entity to stream in (with timeout)
  local grill = lib.waitFor(function()
    local entity = NetworkGetEntityFromNetworkId(GlobalState.waiterGrill)
    if DoesEntityExist(entity) then
      return entity
    end
  end, 'Grill entity failed to stream in', 10000)

  if not grill then
    lib.print.error('Grill entity does not exist after timeout')
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
  local centerCoord = vector3(sharedConfig.EntranceCoords.x, sharedConfig.EntranceCoords.y, sharedConfig.EntranceCoords
    .z)
  local deletedCount = 0

  -- Get ALL objects in the world
  local allObjects = GetGamePool('CObject')

  for _, obj in ipairs(allObjects) do
    local model = GetEntityModel(obj)
    local coords = GetEntityCoords(obj)
    local dist = #(coords - centerCoord)

    -- Check if this object is one of our target hashes and within radius
    local isTargetHash = false
    for _, hash in ipairs(sharedConfig.PropsToDelete) do
      if model == hash then
        isTargetHash = true
        break
      end
    end

    if isTargetHash and dist <= clientConfig.CleanupRadius then
      -- Check if this is one of OUR spawned entities by network ID
      local objNetId = NetworkGetNetworkIdFromEntity(obj)
      local isOurFurniture = false

      -- Check against furniture in GlobalState
      if GlobalState.waiterFurniture then
        for _, item in ipairs(GlobalState.waiterFurniture) do
          if item.netid == objNetId then
            isOurFurniture = true
            break
          end
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
  local alreadySetup = GlobalState.waiterFurniture ~= nil

  -- If not already setup, request server to spawn
  if not alreadySetup then
    CleanupScene()
    lib.print.info('Requesting server to spawn furniture')

    local success = lib.callback.await('waiter:server:setupRestaurant', false)
    if not success then
      lib.notify({ type = 'error', description = 'Failed to setup restaurant' })
      return
    end

    -- Start customer spawning (only needed once)
    lib.callback.await('waiter:server:startCustomerSpawning', false)
  else
    lib.notify({ type = 'info', description = 'Restaurant is already set up' })
  end

  -- Wait for GlobalState to be populated
  local furniture = lib.waitFor(function()
    if GlobalState.waiterFurniture then return GlobalState.waiterFurniture end
  end, 'Furniture not spawned by server', 5000)

  if not furniture then
    lib.notify({ type = 'error', description = 'Failed to load restaurant' })
    return
  end

  -- Load furniture entities and populate seat tracking
  lib.print.info(('Processing %d furniture pieces'):format(#furniture))
  for _, item in ipairs(furniture) do
    -- Wait for entity to stream in
    local obj = lib.waitFor(function()
      local entity = NetworkGetEntityFromNetworkId(item.netid)
      if DoesEntityExist(entity) then
        return entity
      end
    end, ('Furniture %s failed to stream in'):format(item.type), 10000)

    if obj and item.type == 'chair' then
      local finalCoords = GetEntityCoords(obj)
      table.insert(State.validSeats, {
        netid = item.netid,
        coords = vector4(finalCoords.x, finalCoords.y, finalCoords.z, item.coords.w),
        isOccupied = false,
        id = #State.validSeats + 1
      })
    end
  end

  -- Clean up world props now that we know what's ours
  DeleteWorldProps()

  SetupKitchen()
  State.isRestaurantOpen = true
  lib.print.info(('Restaurant %s! Seats: %d'):format(alreadySetup and 'joined' or 'opened', #State.validSeats))

  -- Thread: Keep world props deleted
  CreateThread(function()
    while State.isRestaurantOpen do
      DeleteWorldProps()
      Wait(2000)
    end
  end)
end
