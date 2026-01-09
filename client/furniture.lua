-- Furniture and Restaurant Setup
local clientConfig = require 'config.client'
local sharedConfig = require 'config.shared'

local isInProximity = false
local cleanupThreadActive = false
local grillTargetRegistered = false

-- Get entrance coords as vec3
local function GetEntranceVec3()
  return vector3(sharedConfig.EntranceCoords.x, sharedConfig.EntranceCoords.y, sharedConfig.EntranceCoords.z)
end

-- Check if player is within restaurant proximity
local function IsPlayerInRange()
  local playerCoords = GetEntityCoords(cache.ped)
  local entrance = GetEntranceVec3()
  return #(playerCoords - entrance) <= sharedConfig.ProximityRadius
end

-- Setup kitchen grill ox_target using model-based targeting
-- This works regardless of entity streaming - ox_target handles it internally
function SetupKitchenTarget()
  if grillTargetRegistered then return end

  local grillHash = sharedConfig.KitchenGrill.hash
  local options = {}

  -- Generate Add Options
  for k, v in pairs(sharedConfig.Items) do
    table.insert(options, {
      name = 'waiter_add_' .. k,
      icon = 'fa-solid fa-plus',
      label = 'Pick up ' .. v.label,
      distance = 2.0,
      canInteract = function(entity)
        -- Only show if restaurant is open and entity is our grill
        if not GlobalState.waiterGrill then return false end
        local grillEntity = NetworkGetEntityFromNetworkId(GlobalState.waiterGrill)
        return entity == grillEntity
      end,
      onSelect = function() ModifyHand('add', k) end
    })
  end

  -- Clear Tray Option
  table.insert(options, {
    name = 'waiter_clear_tray',
    icon = 'fa-solid fa-trash',
    label = 'Clear Tray',
    distance = 2.0,
    canInteract = function(entity)
      if not GlobalState.waiterGrill then return false end
      local grillEntity = NetworkGetEntityFromNetworkId(GlobalState.waiterGrill)
      return entity == grillEntity
    end,
    onSelect = function() ModifyHand('clear') end
  })

  exports.ox_target:addModel(grillHash, options)
  grillTargetRegistered = true
  lib.print.info('Grill target options registered (model-based)')
end

-- Remove kitchen target (for cleanup)
function RemoveKitchenTarget()
  if not grillTargetRegistered then return end

  local grillHash = sharedConfig.KitchenGrill.hash

  -- Remove all our options by name
  for k, _ in pairs(sharedConfig.Items) do
    exports.ox_target:removeModel(grillHash, 'waiter_add_' .. k)
  end
  exports.ox_target:removeModel(grillHash, 'waiter_clear_tray')

  grillTargetRegistered = false
  lib.print.info('Grill target options removed')
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

    if isTargetHash and dist <= sharedConfig.ProximityRadius then
      -- Check if this is one of OUR spawned entities by network ID
      local isOurFurniture = false

      -- Only check network ID if entity is networked (world props aren't)
      if NetworkGetEntityIsNetworked(obj) then
        local objNetId = NetworkGetNetworkIdFromEntity(obj)

        -- Check against furniture in GlobalState
        if GlobalState.waiterFurniture then
          for _, item in ipairs(GlobalState.waiterFurniture) do
            if item.netid == objNetId then
              isOurFurniture = true
              break
            end
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

  -- Request server to spawn if not already setup
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
    lib.print.info('Restaurant already running, loading furniture data')
  end

  -- Load furniture data
  LoadFurnitureData()

  -- Register ox_target for grill (model-based, works regardless of streaming)
  SetupKitchenTarget()

  -- Start proximity management thread
  StartProximityManagement()
end

-- Load furniture entities and populate seat tracking (called from various places)
function LoadFurnitureData()
  if State.isRestaurantOpen then
    lib.print.info('Furniture already loaded')
    return
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

  State.isRestaurantOpen = true
  lib.print.info(('Furniture loaded! Seats: %d'):format(#State.validSeats))
end

-- Proximity management thread - handles cleanup and exit detection
function StartProximityManagement()
  if cleanupThreadActive then return end
  cleanupThreadActive = true

  CreateThread(function()
    lib.print.info('Proximity management thread started')

    while State.isRestaurantOpen do
      local wasInProximity = isInProximity
      isInProximity = IsPlayerInRange()

      -- Player entered proximity
      if isInProximity and not wasInProximity then
        lib.print.info('Player entered restaurant area')
        DeleteWorldProps() -- Initial cleanup on entry
      end

      -- Player left proximity
      if not isInProximity and wasInProximity then
        lib.print.info('Player left restaurant area')
        ModifyHand('clear')
        lib.notify({ type = 'info', description = 'Tray cleared (Left Area)' })
      end

      -- Periodic cleanup while in proximity (world props can respawn)
      if isInProximity then
        DeleteWorldProps()
      end

      Wait(2000) -- Check every 2 seconds
    end

    cleanupThreadActive = false
    lib.print.info('Proximity management thread stopped')
  end)
end

-- Watch for GlobalState changes to handle late-joining players or remote setup
AddStateBagChangeHandler('waiterGrill', 'global', function(_, _, value)
  if value then
    lib.print.info('GlobalState.waiterGrill changed, setting up target options')
    SetupKitchenTarget()
  else
    lib.print.info('GlobalState.waiterGrill cleared, removing target options')
    RemoveKitchenTarget()
  end
end)

-- Watch for furniture changes (for late-joining players)
AddStateBagChangeHandler('waiterFurniture', 'global', function(_, _, value)
  if value and not State.isRestaurantOpen then
    lib.print.info('GlobalState.waiterFurniture detected, auto-loading')
    -- Small delay to ensure grill state is also set
    SetTimeout(500, function()
      LoadFurnitureData()
      SetupKitchenTarget()
      StartProximityManagement()
    end)
  end
end)

-- Initialize on resource start
CreateThread(function()
  Wait(1000) -- Let ox_lib and other resources initialize

  -- Check if restaurant is already running (e.g., player joined mid-session or resource restart)
  if GlobalState.waiterFurniture then
    lib.print.info('Restaurant already running on resource start, auto-loading')
    LoadFurnitureData()
    SetupKitchenTarget()
    StartProximityManagement()
  end
end)
