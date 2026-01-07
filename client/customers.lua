-- Customer Spawning and Management
local config = require 'config.client'
local sharedConfig = require 'config.shared'

function CustomerLeave(customer, reason)
  local ped = customer.ped
  local seat = State.validSeats[customer.seatId]

  if seat then seat.isOccupied = false end

  -- Remove ox_target interactions before leaving
  if DoesEntityExist(ped) then
    exports.ox_target:removeLocalEntity(ped)
  end

  if reason == "angry" and DoesEntityExist(ped) then
    lib.notify({ type = 'warning', description = 'Customer left angry!' })
    PlayAnimUpper(ped, config.Anims.Anger.dict, config.Anims.Anger.anim)
    Wait(1500)
  end

  if not DoesEntityExist(ped) then return end

  -- Re-apply ghosting through all furniture when leaving
  for _, prop in pairs(State.spawnedProps) do
    if DoesEntityExist(prop) then
      SetEntityNoCollisionEntity(prop, ped, false)
    end
  end

  -- Walk to exit
  ClearPedTasksImmediately(ped)
  TaskGoToCoordAnyMeans(ped, config.EntranceCoords.x, config.EntranceCoords.y, config.EntranceCoords.z, 1.0, 0, false,
    786603, 0xbf800000)

  -- Final Delete
  SetTimeout(10000, function()
    if DoesEntityExist(ped) then
      for i = 255, 0, -50 do
        SetEntityAlpha(ped, i, false)
        Wait(50)
      end
      SafeDelete(ped)
      for k, v in pairs(State.allPeds) do
        if v == ped then
          table.remove(State.allPeds, k)
          break
        end
      end
    end
  end)

  -- Remove from active customer logic list
  for k, v in pairs(State.customers) do
    if v == customer then
      table.remove(State.customers, k)
      break
    end
  end
end

function StartCustomerLogic(customer)
  CreateThread(function()
    local seat = State.validSeats[customer.seatId]
    if not seat then
      SafeDelete(customer.ped)
      return
    end

    local ped = customer.ped
    local walkStart = GetGameTimer()

    -- 1. Walk In
    TaskGoToCoordAnyMeans(ped, seat.coords.x, seat.coords.y, seat.coords.z, 1.0, 0, false, 786603, 0xbf800000)

    while #(GetEntityCoords(ped) - vector3(seat.coords.x, seat.coords.y, seat.coords.z)) > 1.7 do
      if not State.validSeats[customer.seatId] then return end
      if (GetGameTimer() - walkStart) > config.WalkTimeout then
        seat.isOccupied = false
        SafeDelete(ped)
        return
      end
      Wait(500)
    end

    -- 2. Sit
    if not DoesEntityExist(ped) then return end
    ClearPedTasks(ped)
    local seatH = (seat.coords.w + 180.0) % 360.0
    TaskStartScenarioAtPosition(ped, "PROP_HUMAN_SEAT_CHAIR", seat.coords.x, seat.coords.y, seat.coords.z + 0.50, seatH,
      -1, true, true)

    Wait(4000)
    customer.status = "waiting_order"
    customer.patienceTimer = GetGameTimer()

    -- 3. Loop
    while DoesEntityExist(ped) and customer.status ~= "eating" do
      -- Patience Check
      local maxWait = (customer.status == "waiting_order") and config.PatienceOrder or config.PatienceFood
      if (GetGameTimer() - customer.patienceTimer) > maxWait then
        CustomerLeave(customer, "angry")
        return
      end

      -- Waving (Only if waiting for order)
      if customer.status == "waiting_order" then
        Wait(math.random(config.WaveIntervalMin, config.WaveIntervalMax))
        if DoesEntityExist(ped) and customer.status == "waiting_order" then
          PlayAnimUpper(ped, config.Anims.Wave.dict, config.Anims.Wave.anim)
        end
      else
        Wait(1000)
      end
    end
  end)
end

function DeliverFood(customer)
  local ped = customer.ped
  local tray = GetMyTray()

  -- Match tray items with customer order
  local matchedItems, itemsDelivered = MatchTrayWithOrder(tray, customer.order)

  -- Tell server to remove delivered items
  if itemsDelivered > 0 then
    for _, item in ipairs(matchedItems) do
      TriggerServerEvent('waiter:server:modifyTray', 'remove', item)
    end
  end

  -- Process Results
  if itemsDelivered > 0 then
    if #customer.order == 0 then
      -- Order Complete
      customer.status = "eating"
      lib.notify({ type = 'success', description = 'Order Delivered! Customer is happy.' })

      -- Payment: Trigger server event
      TriggerServerEvent('waiter:pay', itemsDelivered)

      PlayAnimUpper(ped, config.Anims.Eat.dict, config.Anims.Eat.anim, true)
      Wait(config.EatTime)

      CustomerLeave(customer, "happy")
    else
      -- Partial Delivery
      local remainingStr = ""
      for _, v in pairs(customer.order) do
        remainingStr = remainingStr .. sharedConfig.Items[v].label .. ", "
      end

      lib.notify({
        type = 'info',
        title = 'Partial Delivery',
        description = 'Gave ' .. itemsDelivered .. ' item(s).\nStill needs: ' .. remainingStr
      })
    end
  else
    -- No Matches
    local orderStr = ""
    for _, v in pairs(customer.order) do
      orderStr = orderStr .. sharedConfig.Items[v].label .. ", "
    end
    lib.notify({ type = 'error', description = 'Wrong Items! Customer needs: ' .. orderStr })
  end
end

function SpawnSingleCustomer()
  local seat = nil
  for _, s in ipairs(State.validSeats) do
    if not s.isOccupied then
      seat = s
      break
    end
  end
  if not seat then return end

  local model = config.Models[math.random(1, #config.Models)]
  lib.requestModel(model)
  local ped = CreatePed(4, joaat(model), config.EntranceCoords.x, config.EntranceCoords.y, config.EntranceCoords.z,
    config.EntranceCoords.w, true, false)

  -- Make customer ghost through all furniture from the start
  for _, prop in pairs(State.spawnedProps) do
    if DoesEntityExist(prop) then
      SetEntityNoCollisionEntity(prop, ped, false)
    end
  end

  seat.isOccupied = true
  table.insert(State.allPeds, ped)

  local customerData = {
    ped = ped,
    seatId = seat.id,
    status = "walking_in",
    patienceTimer = 0,
    order = {}
  }
  table.insert(State.customers, customerData)

  -- Interactions
  exports.ox_target:addLocalEntity(ped, {
    {
      name = 'take_order',
      label = 'Take Order',
      icon = 'fa-solid fa-clipboard',
      distance = 2.0,
      canInteract = function() return customerData.status == "waiting_order" end,
      onSelect = function()
        local itemCount = math.random(1, sharedConfig.MaxHandItems)
        local itemKeys = { 'burger', 'drink', 'fries' }
        local orderText = ""

        for i = 1, itemCount do
          local item = itemKeys[math.random(1, #itemKeys)]
          table.insert(customerData.order, item)
          orderText = orderText .. sharedConfig.Items[item].label .. (i < itemCount and ", " or "")
        end

        lib.notify({ title = 'New Order', description = orderText, type = 'info', duration = 10000 })
        customerData.status = "waiting_food"
        customerData.patienceTimer = GetGameTimer()
      end
    },
    {
      name = 'deliver_food',
      label = 'Deliver Food',
      icon = 'fa-solid fa-utensils',
      distance = 2.0,
      canInteract = function() return customerData.status == "waiting_food" end,
      onSelect = function()
        DeliverFood(customerData)
      end
    }
  })

  StartCustomerLogic(customerData)
end
