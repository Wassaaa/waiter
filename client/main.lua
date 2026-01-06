-- Main Client Entry Point

-- Commands
RegisterCommand('setuprest', function()
  SetupRestaurant()
end, false)

RegisterCommand('newcustomer', function()
  SpawnSingleCustomer()
end, false)

RegisterCommand('closerest', function()
  CleanupScene()
  lib.notify({ type = 'info', description = 'Restaurant Closed' })
end, false)

-- Tray Adjustment (Debug)
RegisterCommand('tunetray', function(source, args)
  if not State.trayProp or not DoesEntityExist(State.trayProp) then return end

  local x = tonumber(args[1]) or 0.1
  local y = tonumber(args[2]) or 0.05
  local z = tonumber(args[3]) or -0.1
  local rx = tonumber(args[4]) or 180.0
  local ry = tonumber(args[5]) or 180.0
  local rz = tonumber(args[6]) or 0.0

  AttachEntityToEntity(State.trayProp, PlayerPedId(), GetPedBoneIndex(PlayerPedId(), 57005), x, y, z, rx, ry, rz, true,
    true, false, true, 1, true)
  print(string.format("Adjusted: %.2f %.2f %.2f | %.2f %.2f %.2f", x, y, z, rx, ry, rz))
end, false)

-- Resource Cleanup
AddEventHandler('onResourceStop', function(resourceName)
  if GetCurrentResourceName() ~= resourceName then return end
  CleanupScene()
  ModifyHand('clear')
end)

local knownModels = {
  [joaat('prop_chair_01a')] = 'prop_table_01',
  [joaat('prop_chair_02')] = 'prop_chair_01a',
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

-- Auto-Start Restaurant (Debug)
if Config.AutoStartRestaurant then
  CreateThread(function()
    Wait(1000)
    print("^3[Dev] Auto-Starting Restaurant Setup...^7")
    SetupRestaurant()
  end)
end
