-- Furniture and Restaurant Setup
local clientConfig = require 'config.client'
local sharedConfig = require 'config.shared'

local isInProximity = false
local cleanupThreadActive = false
local kitchenTargetsRegistered = {} -- Track registered kitchen targets by hash

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

-- Check if entity is one of our kitchen props
---@param entity number Entity handle to check
---@return table|nil Kitchen data if found, nil otherwise
local function GetKitchenByEntity(entity)
  if not GlobalState.waiterFurniture then return nil end

  for _, item in ipairs(GlobalState.waiterFurniture) do
    if item.type == 'kitchen' then
      local kitchenEntity = NetworkGetEntityFromNetworkId(item.netid)
      if kitchenEntity == entity then
        return item
      end
    end
  end
  return nil
end

-- Setup ox_target options for all kitchen props
-- Uses model-based targeting with canInteract to verify specific entities
function SetupKitchenTargets()
  if not GlobalState.waiterFurniture then return end

  for _, kitchen in ipairs(GlobalState.waiterFurniture) do
    if kitchen.type ~= 'kitchen' then goto continue end
    if kitchenTargetsRegistered[kitchen.hash] then goto continue end

    local options = {}
    local defaults = sharedConfig.TargetDefaults

    -- Add options for each action this kitchen supports
    for _, actionKey in ipairs(kitchen.actions or {}) do
      local itemData = sharedConfig.Items[actionKey]
      if itemData then
        local target = itemData.target or {}
        local action = target.action or defaults.action

        table.insert(options, {
          name = 'waiter_' .. actionKey,
          icon = target.icon or defaults.icon,
          label = target.label or defaults.label:format(itemData.label or actionKey),
          distance = target.distance or defaults.distance,
          canInteract = function(entity)
            local k = GetKitchenByEntity(entity)
            if not k or not k.actions then return false end
            for _, a in ipairs(k.actions) do
              if a == actionKey then return true end
            end
            return false
          end,
          onSelect = function() ModifyHand(action, actionKey) end
        })
      end
    end

    if #options > 0 then
      exports.ox_target:addModel(kitchen.hash, options)
      kitchenTargetsRegistered[kitchen.hash] = true
      lib.print.info(('Kitchen target registered: hash=%s options=%d'):format(kitchen.hash, #options))
    end

    ::continue::
  end
end

-- Remove all kitchen target options
function RemoveKitchenTargets()
  for hash, _ in pairs(kitchenTargetsRegistered) do
    -- Remove all possible action options
    for actionKey, _ in pairs(sharedConfig.Items) do
      exports.ox_target:removeModel(hash, 'waiter_' .. actionKey)
    end
    lib.print.info(('Kitchen target removed for hash %s'):format(hash))
  end
  kitchenTargetsRegistered = {}
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

  -- Register ox_target for kitchen props (model-based, works regardless of streaming)
  SetupKitchenTargets()

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
AddStateBagChangeHandler('waiterFurniture', 'global', function(_, _, value)
  if value then
    lib.print.info('GlobalState.waiterFurniture changed, setting up kitchen targets')
    SetupKitchenTargets()
  else
    lib.print.info('GlobalState.waiterFurniture cleared, removing kitchen targets')
    RemoveKitchenTargets()
  end
end)



-- Initialize on resource start
CreateThread(function()
  Wait(1000) -- Let ox_lib and other resources initialize

  -- Check if restaurant is already running (e.g., player joined mid-session or resource restart)
  if GlobalState.waiterFurniture then
    lib.print.info('Restaurant already running on resource start, auto-loading')
    LoadFurnitureData()
    SetupKitchenTargets()
    StartProximityManagement()
  end
end)
