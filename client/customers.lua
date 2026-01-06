-- Customer Spawning and Management

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
    PlayAnimUpper(ped, Config.Anims.Anger.dict, Config.Anims.Anger.anim)
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
  TaskGoToCoordAnyMeans(ped, Config.EntranceCoords.x, Config.EntranceCoords.y, Config.EntranceCoords.z, 1.0, 0, false,
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
      if (GetGameTimer() - walkStart) > Config.WalkTimeout then
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
      local maxWait = (customer.status == "waiting_order") and Config.PatienceOrder or Config.PatienceFood
      if (GetGameTimer() - customer.patienceTimer) > maxWait then
        CustomerLeave(customer, "angry")
        return
      end

      -- Waving (Only if waiting for order)
      if customer.status == "waiting_order" then
        Wait(math.random(Config.WaveIntervalMin, Config.WaveIntervalMax))
        if DoesEntityExist(ped) and customer.status == "waiting_order" then
          PlayAnimUpper(ped, Config.Anims.Wave.dict, Config.Anims.Wave.anim)
        end
      else
        Wait(1000)
      end
    end
  end)
end

function DeliverFood(customer)
  local ped = customer.ped
  local itemsDelivered = 0

  -- Loop backwards
  local i = #State.handContent
  while i > 0 do
    local heldItem = State.handContent[i]
    local matchIndex = nil

    -- Check if customer needs this specific item
    for orderIdx, neededItem in ipairs(customer.order) do
      if neededItem == heldItem then
        matchIndex = orderIdx
        break
      end
    end

    if matchIndex then
      table.remove(customer.order, matchIndex)
      table.remove(State.handContent, i)
      itemsDelivered = itemsDelivered + 1
    end

    i = i - 1
  end

  -- Process Results
  if itemsDelivered > 0 then
    UpdateHandVisuals()

    if #customer.order == 0 then
      -- Order Complete
      customer.status = "eating"
      lib.notify({ type = 'success', description = 'Order Delivered! Customer is happy.' })

      -- TODO: Payment
      -- TriggerServerEvent('waiter:pay', itemsDelivered * Config.PayPerItem)

      PlayAnimUpper(ped, Config.Anims.Eat.dict, Config.Anims.Eat.anim, true)
      Wait(Config.EatTime)

      CustomerLeave(customer, "happy")
    else
      -- Partial Delivery
      local remainingStr = ""
      for _, v in pairs(customer.order) do
        remainingStr = remainingStr .. Config.Items[v].label .. ", "
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
      orderStr = orderStr .. Config.Items[v].label .. ", "
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

  local model = Config.Models[math.random(1, #Config.Models)]
  lib.requestModel(model)
  local ped = CreatePed(4, joaat(model), Config.EntranceCoords.x, Config.EntranceCoords.y, Config.EntranceCoords.z,
    Config.EntranceCoords.w, true, false)

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
        local itemCount = math.random(1, Config.MaxHandItems)
        local itemKeys = { 'burger', 'drink', 'fries' }
        local orderText = ""

        for i = 1, itemCount do
          local item = itemKeys[math.random(1, #itemKeys)]
          table.insert(customerData.order, item)
          orderText = orderText .. Config.Items[item].label .. (i < itemCount and ", " or "")
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
