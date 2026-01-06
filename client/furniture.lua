-- Furniture and Restaurant Setup

function SetupKitchen()
  local options = {}

  -- Generate Add Options
  for k, v in pairs(Config.Items) do
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

  -- Spawn Grill
  local cooker = Config.KitchenGrill
  lib.requestModel(cooker.hash)
  local grill = CreateObject(cooker.hash, cooker.coords.x, cooker.coords.y, cooker.coords.z, false, false, false)
  PlaceObjectOnGroundProperly(grill)
  SetEntityHeading(grill, cooker.coords.w)
  FreezeEntityPosition(grill, true)
  table.insert(State.spawnedProps, grill)

  exports.ox_target:addLocalEntity(grill, options)
  State.kitchenGrill = grill
end

function DeleteWorldProps()
  local propsToDelete = {
    joaat('prop_chair_01a'),
    joaat('prop_table_01')
  }

  for _, item in ipairs(Config.Furniture) do
    local existingProp = GetClosestObjectOfType(item.coords.x, item.coords.y, item.coords.z, 0.5, item.hash, false, false,
      false)

    while DoesEntityExist(existingProp) do
      local propModel = GetEntityModel(existingProp)
      local isTargetModel = false

      for _, modelHash in ipairs(propsToDelete) do
        if propModel == modelHash then
          isTargetModel = true
          break
        end
      end

      local isOurProp = false
      for _, ourProp in pairs(State.spawnedProps) do
        if existingProp == ourProp then
          isOurProp = true
          break
        end
      end

      if isTargetModel and not isOurProp then
        SetEntityAsMissionEntity(existingProp, true, true)
        DeleteObject(existingProp)
      else
        break
      end

      existingProp = GetClosestObjectOfType(item.coords.x, item.coords.y, item.coords.z, 0.5, item.hash, false, false,
        false)
    end
  end
end

function SetupRestaurant()
  CleanupScene()
  DeleteWorldProps()

  -- Spawn Furniture
  for i, item in ipairs(Config.Furniture) do
    lib.requestModel(item.hash)
    local obj = CreateObject(item.hash, item.coords.x, item.coords.y, item.coords.z, false, false, false)
    PlaceObjectOnGroundProperly(obj)
    SetEntityHeading(obj, item.coords.w)
    FreezeEntityPosition(obj, true)
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

  SetupKitchen()
  State.isRestaurantOpen = true
  print("^2[Waiter Job] Restaurant Open! Seats: " .. #State.validSeats .. "^7")

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
      Wait(Config.SpawnInterval)
      if State.isRestaurantOpen then SpawnSingleCustomer() end
    end
  end)
end
