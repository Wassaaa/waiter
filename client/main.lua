-- Main Client Entry Point
local clientConfig = require 'config.client'
local sharedConfig = require 'config.shared'

---Setup the OX Target management zone for the restaurant
local function SetupManagementZone()
  local mgmt = sharedConfig.Management
  if not mgmt then return end

  exports.ox_target:addSphereZone({
    coords = mgmt.coords,
    radius = mgmt.radius,
    debug = false,
    options = {
      {
        name = 'waiter_open',
        icon = mgmt.target.open.icon,
        label = mgmt.target.open.label,
        canInteract = function()
          if not State.IsWaiter() then return false end
          return not GlobalState.WaiterOpen
        end,
        onSelect = function()
          TriggerServerEvent('waiter:server:toggleRestaurant')
        end
      },
      {
        name = 'waiter_close',
        icon = mgmt.target.close.icon,
        label = mgmt.target.close.label,
        canInteract = function()
          if not State.IsWaiter() then return false end
          return GlobalState.WaiterOpen
        end,
        onSelect = function()
          TriggerServerEvent('waiter:server:toggleRestaurant')
        end
      }
    }
  })
  lib.print.info('Management zone setup at ' .. tostring(mgmt.coords))
end

-- Job Events
local function UpdateJob(job)
  State.PlayerJob = job
end

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
  local player = exports.qbx_core:GetPlayerData()
  lib.print.info("I loaded")
  if player then UpdateJob(player.job) end
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(JobInfo)
  UpdateJob(JobInfo)
end)

-- Initialize
CreateThread(function()
  if GetResourceState('qbx_core') == 'started' then
    local player = exports.qbx_core:GetPlayerData()
    if player then UpdateJob(player.job) end
  end
end)

-- Monitor Global State Changes
AddStateBagChangeHandler('WaiterOpen', 'global', function(bagName, key, value, _reserved, replicated)
  lib.print.info(('Restaurant state (%s) changed to: %s (Replicated: %s)'):format(bagName, tostring(value),
    tostring(replicated)))
end)

-- Initialize
SetupManagementZone()

local knownModels = {
  [joaat('prop_chair_01a')] = 'prop_chair_01a',
  [joaat('prop_table_01')] = 'prop_table_01',
}

RegisterCommand('stealscene', function(source, args)
  local playerPed = PlayerPedId()
  local playerCoords = GetEntityCoords(playerPed)

  local radius = tonumber(args[1]) or 5.0

  -- Helper to guess prop type from name
  local function getType(name)
    local lower = string.lower(name)
    if string.find(lower, 'chair') then
      return 'chair'
    elseif string.find(lower, 'table') then
      return 'table'
    elseif string.find(lower, 'plant') or string.find(lower, 'pot') then
      return 'decoration'
    else
      return 'prop'
    end
  end

  print("^3[Dev] Scanning radius: " .. radius .. "m^7")
  print("Config.Furniture = {")

  local pool = GetGamePool('CObject')
  for i = 1, #pool do
    local object = pool[i]
    local coords = GetEntityCoords(object)
    local dist = #(playerCoords - coords)

    if dist < radius then
      local hash = GetEntityModel(object)
      local heading = GetEntityHeading(object)

      -- Try to find the name (add your known models here)
      local name = knownModels[hash]

      if name then
        local propType = getType(name)

        -- Formatting helper
        local function r(num) return tonumber(string.format("%.2f", num)) end

        print(string.format("    { type = '%s', hash = joaat('%s'), coords = vector4(%s, %s, %s, %s) },",
          propType, name, r(coords.x), r(coords.y), r(coords.z), r(heading)
        ))
      else
        -- Unknown hash - output with warning
        local function r(num) return tonumber(string.format("%.2f", num)) end
        print(string.format("    -- UNKNOWN: { type = 'unknown', hash = %s, coords = vector4(%s, %s, %s, %s) },",
          hash, r(coords.x), r(coords.y), r(coords.z), r(heading)
        ))
      end

      -- Draw Red Line to object
      DrawLine(playerCoords.x, playerCoords.y, playerCoords.z, coords.x, coords.y, coords.z, 255, 0, 0, 255)
    end
  end
  print("}")
  print("^2--------------------------------------^7")
  lib.notify({ title = 'Scene Dumped', description = 'Radius: ' .. radius .. 'm (Check F8)', type = 'success' })
end)

-- Dependency checks
lib.checkDependency('ox_lib', '3.0.0', true)
lib.checkDependency('ox_target', '1.0.0', true)
lib.checkDependency('qbx_core', '1.0.0', true)
