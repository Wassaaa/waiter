-- Furniture and Restaurant Setup
local clientConfig = require 'config.client'
local sharedConfig = require 'config.shared'

local isInProximity = false
local cleanupThreadActive = false
local kitchenTargetsRegistered = {} -- Track registered kitchen targets by hash

-- Check if player is within restaurant proximity
local function IsPlayerInRange()
  local playerCoords = GetEntityCoords(cache.ped)
  return #(playerCoords - sharedConfig.RestaurantCenter) <= sharedConfig.ProximityRadius
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

-- Helper alias
local IsWaiter = State.IsWaiter

-- Setup ox_target options for all kitchen props
-- Uses model-based targeting with canInteract to verify specific entities
function SetupKitchenTargets()
  if not GlobalState.waiterFurniture then return end

  for _, kitchen in ipairs(GlobalState.waiterFurniture) do
    if kitchen.type ~= 'kitchen' then goto continue end
    if kitchenTargetsRegistered[kitchen.hash] then goto continue end

    local options = {}
    local defaults = sharedConfig.TargetDefaults

    -- Split actions into food and utility
    local hasFood = false

    -- Process utility actions explicitly
    -- Individual food interactions removed in favor of Tray Building Minigame
    -- Allow tray assembly if kitchen has any actions (Simplification)
    if kitchen.actions and #kitchen.actions > 0 then
      hasFood = true
    end

    -- Add single 'Assemble Tray' option if any food is available
    if hasFood then
      table.insert(options, {
        name = 'waiter_tray_build',
        icon = 'fa-solid fa-utensils',
        label = 'Assemble Tray',
        distance = 2.0,
        canInteract = function(entity)
          if not IsWaiter() then return false end
          local k = GetKitchenByEntity(entity)
          if not k or not k.actions then return false end

          -- Check if ANY food action is present on this specific entity
          for _, a in ipairs(k.actions) do
            local d = sharedConfig.Actions[a]
            if d and d.type == 'food' then return true end
          end
          return false
        end,
        onSelect = function() StartTrayBuilding() end
      })
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
    for actionKey, _ in pairs(sharedConfig.Actions) do
      exports.ox_target:removeModel(hash, 'waiter_' .. actionKey)
    end
    lib.print.info(('Kitchen target removed for hash %s'):format(hash))
  end
  kitchenTargetsRegistered = {}
end

-- Manage world prop hiding (persistent engine-level hiding)
function ManageModelHides(enable)
  local center = sharedConfig.RestaurantCenter
  local radius = sharedConfig.ProximityRadius

  for _, hash in ipairs(sharedConfig.PropsToDelete) do
    if enable then
      CreateModelHideExcludingScriptObjects(center.x, center.y, center.z, radius, hash, true)
    else
      RemoveModelHide(center.x, center.y, center.z, radius, hash, false)
    end
  end

  if enable then
    lib.print.info('World props hidden via engine')
  else
    lib.print.info('World props restored')
  end
end

-- Load furniture entities and populate seat tracking
function LoadFurnitureData()
  if State.restaurantLoaded then
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

  ManageModelHides(true)

  -- Force ground items (client-side physics adjustment)
  for _, item in ipairs(furniture) do
    if NetworkDoesNetworkIdExist(item.netid) then
      local entity = NetworkGetEntityFromNetworkId(item.netid)
      if DoesEntityExist(entity) then
        FreezeEntityPosition(entity, false)
        PlaceObjectOnGroundProperly(entity)
        SetEntityRotation(entity, 0.0, 0.0, item.coords.w, 2, true)
        FreezeEntityPosition(entity, true)
      end
    end
  end

  State.restaurantLoaded = true
  lib.print.info('Furniture loaded!')
end

-- Disable collision on chairs to allow ped navigation
local function UpdateFurnitureCollision()
  if not GlobalState.waiterFurniture then return end

  for _, item in ipairs(GlobalState.waiterFurniture) do
    if item.type == 'chair' then
      if NetworkDoesNetworkIdExist(item.netid) then
        local entity = NetworkGetEntityFromNetworkId(item.netid)
        if DoesEntityExist(entity) then
          -- Disable collision completely (ghost mode)
          SetEntityCollision(entity, false, false)
        end
      end
    end
  end
end

-- Proximity management thread
function StartProximityManagement()
  if cleanupThreadActive then return end
  cleanupThreadActive = true

  CreateThread(function()
    lib.print.info('Proximity management thread started')

    while State.restaurantLoaded do
      local wasInProximity = isInProximity
      isInProximity = IsPlayerInRange()

      -- Player entered proximity
      if isInProximity and not wasInProximity then
        lib.print.info('Player entered restaurant area')
        UpdateFurnitureCollision()
      end

      -- Player left proximity
      if not isInProximity and wasInProximity then
        lib.print.info('Player left restaurant area')
        if #GetMyTray() > 0 then
          TriggerServerEvent('waiter:server:modifyTray', 'clear')
          lib.notify({ type = 'info', description = 'Tray cleared (Left Area)' })
        end
      end

      -- Periodic cleanup while in proximity (world props can respawn)
      if isInProximity then
        UpdateFurnitureCollision()
      end

      Wait(2000)
    end

    cleanupThreadActive = false
    lib.print.info('Proximity management thread stopped')
  end)
end

-- Watch for GlobalState changes to handle late-joining players or remote setup
AddStateBagChangeHandler('waiterFurniture', 'global', function(_, _, value)
  if value then
    lib.print.info('GlobalState.waiterFurniture changed, loading furniture')
    LoadFurnitureData()
    SetupKitchenTargets()
    StartProximityManagement()
  else
    lib.print.info('GlobalState.waiterFurniture cleared, cleaning up')
    CleanupScene()
    ManageModelHides(false)
  end
end)

-- Initialize on resource start
CreateThread(function()
  Wait(1000) -- Let ox_lib and other resources initialize

  -- Check if restaurant is already running
  if GlobalState.waiterFurniture then
    lib.print.info('Restaurant running on start, loading furniture')
    LoadFurnitureData()
    SetupKitchenTargets()
    StartProximityManagement()
  end
end)
