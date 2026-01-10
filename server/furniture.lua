-- Furniture Spawning and Management
local sharedConfig = require 'config.shared'

ServerFurniture = {}

---Spawn a single prop entity with proper setup
---@param item table Config item with hash, coords, type
---@return number|nil entity The spawned entity handle
---@return number|nil netid The network ID of the spawned entity
local function SpawnProp(item)
  local obj = CreateObject(item.hash, item.coords.x, item.coords.y, item.coords.z, true, true, false)

  local success = lib.waitFor(function()
    if DoesEntityExist(obj) then return true end
  end, ('Failed to spawn %s'):format(item.type), 5000)

  if not success or not DoesEntityExist(obj) then
    lib.print.error(('Failed to spawn prop type=%s hash=%s'):format(item.type, item.hash))
    return nil, nil
  end

  SetEntityHeading(obj, item.coords.w)
  FreezeEntityPosition(obj, true)

  local netid = NetworkGetNetworkIdFromEntity(obj)
  return obj, netid
end

---Build furniture data entry from config item and netid
---@param item table Config item
---@param netid number Network ID
---@return table Furniture data for GlobalState
local function BuildFurnitureEntry(item, netid)
  local entry = {
    netid = netid,
    type = item.type,
    hash = item.hash,
    coords = item.coords,
  }

  -- Kitchen props have additional data
  if item.type == 'kitchen' then
    entry.actions = item.actions or {}
  end

  return entry
end

---Cleanup furniture and reset GlobalState
function ServerFurniture.Cleanup()
  if GlobalState.waiterFurniture then
    for _, item in ipairs(GlobalState.waiterFurniture) do
      local entity = NetworkGetEntityFromNetworkId(item.netid)
      if DoesEntityExist(entity) then
        DeleteEntity(entity)
      end
    end
  end

  GlobalState.waiterFurniture = nil
  lib.print.info('Furniture cleaned up')
end

---Setup Restaurant Furniture
---@return boolean success
function ServerFurniture.Setup()
  -- Clean up any existing furniture first
  if GlobalState.waiterFurniture then
    lib.print.info('Cleaning up existing furniture before spawning new')
    ServerFurniture.Cleanup()
    Wait(500)
  end

  local furniture = {}
  local counts = { table = 0, chair = 0, kitchen = 0 }

  lib.print.info('Spawning furniture server-side')
  for _, item in ipairs(sharedConfig.Furniture) do
    local _, netid = SpawnProp(item)

    if netid then
      local entry = BuildFurnitureEntry(item, netid)
      table.insert(furniture, entry)
      counts[item.type] = (counts[item.type] or 0) + 1
    end
  end

  GlobalState.waiterFurniture = furniture

  lib.print.info(('Spawned: %d tables, %d chairs, %d kitchen props'):format(
    counts.table, counts.chair, counts.kitchen
  ))

  return #furniture > 0
end

-- Cleanup on resource stop
AddEventHandler('onResourceStop', function(resourceName)
  if GetCurrentResourceName() ~= resourceName then return end
  ServerFurniture.Cleanup()
end)
