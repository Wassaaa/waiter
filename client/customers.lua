-- Customer Management - Client Side (Statebag-driven)
local config = require 'config.client'
local sharedConfig = require 'config.shared'

-- Track customer peds and their wave threads
local trackedCustomers = {} -- [netid] = { ped, waveThread }

---Handle customer status changes via statebag
---@param ped number The ped entity
---@param customerData table Customer data from statebag
local function handleCustomerStatus(ped, customerData)
  if not DoesEntityExist(ped) then return end

  local status = customerData.status
  local seatCoords = customerData.seatCoords

  -- Apply furniture ghosting
  for _, prop in pairs(State.spawnedProps) do
    if DoesEntityExist(prop) then
      SetEntityNoCollisionEntity(prop, ped, false)
    end
  end

  if status == 'walking_in' then
    -- Walk to seat
    TaskGoToCoordAnyMeans(ped, seatCoords.x, seatCoords.y, seatCoords.z, 1.0, 0, false, 786603, 0xbf800000)

    -- Monitor arrival
    CreateThread(function()
      local walkStart = GetGameTimer()
      while DoesEntityExist(ped) do
        local dist = #(GetEntityCoords(ped) - vector3(seatCoords.x, seatCoords.y, seatCoords.z))
        if dist <= 1.7 then
          -- Arrived at seat, notify server
          TriggerServerEvent('waiter:server:customerArrived', customerData.id)
          break
        end
        if (GetGameTimer() - walkStart) > config.WalkTimeout then
          -- Timeout, let server handle cleanup
          break
        end
        Wait(500)
      end
    end)
  elseif status == 'sitting' then
    -- Sit down
    ClearPedTasks(ped)
    local seatH = (seatCoords.w + 180.0) % 360.0
    TaskStartScenarioAtPosition(ped, "PROP_HUMAN_SEAT_CHAIR", seatCoords.x, seatCoords.y, seatCoords.z + 0.50, seatH, -1,
      true, true)
  elseif status == 'waiting_order' then
    -- Start waving thread (client-side random animation)
    local netid = customerData.netid
    if not trackedCustomers[netid].waveThread then
      trackedCustomers[netid].waveThread = CreateThread(function()
        while trackedCustomers[netid] and DoesEntityExist(ped) do
          local currentData = Entity(ped).state.waiterCustomer
          if currentData and currentData.status == 'waiting_order' then
            Wait(math.random(config.WaveIntervalMin, config.WaveIntervalMax))
            if DoesEntityExist(ped) and Entity(ped).state.waiterCustomer?.status == 'waiting_order' then
              PlayAnimUpper(ped, config.Anims.Wave.dict, config.Anims.Wave.anim)
            end
          else
            break
          end
        end
      end)
    end
  elseif status == 'eating' then
    -- Play eating animation
    PlayAnimUpper(ped, config.Anims.Eat.dict, config.Anims.Eat.anim, true)
  elseif status == 'leaving_angry' then
    -- Angry animation
    lib.notify({ type = 'warning', description = 'Customer left angry!' })
    PlayAnimUpper(ped, config.Anims.Anger.dict, config.Anims.Anger.anim)
    Wait(1500)
    -- Walk to exit and fade out when close
    ClearPedTasksImmediately(ped)
    TaskGoToCoordAnyMeans(ped, config.ExitCoords.x, config.ExitCoords.y, config.ExitCoords.z, 1.0, 0, false, 786603,
      0xbf800000)

    CreateThread(function()
      while DoesEntityExist(ped) do
        local dist = #(GetEntityCoords(ped) - vector3(config.ExitCoords.x, config.ExitCoords.y, config.ExitCoords.z))
        if dist <= 2.0 then
          -- Reached exit, fade out
          for i = 255, 0, -50 do
            SetEntityAlpha(ped, i, false)
            Wait(config.FadeoutDuration / 6) -- Divide by 6 steps (255/50)
          end
          -- Notify server to delete
          TriggerServerEvent('waiter:server:customerExited', customerData.id)
          break
        end
        Wait(500)
      end
    end)
  elseif status == 'leaving_happy' then
    -- Walk to exit and fade out when close
    ClearPedTasksImmediately(ped)
    TaskGoToCoordAnyMeans(ped, config.ExitCoords.x, config.ExitCoords.y, config.ExitCoords.z, 1.0, 0, false, 786603,
      0xbf800000)

    CreateThread(function()
      while DoesEntityExist(ped) do
        local dist = #(GetEntityCoords(ped) - vector3(config.ExitCoords.x, config.ExitCoords.y, config.ExitCoords.z))
        if dist <= 2.0 then
          -- Reached exit, fade out
          for i = 255, 0, -50 do
            SetEntityAlpha(ped, i, false)
            Wait(config.FadeoutDuration / 6)
          end
          -- Notify server to delete
          TriggerServerEvent('waiter:server:customerExited', customerData.id)
          break
        end
        Wait(500)
      end
    end)
  end
end

---Take customer order
---@param customerData table Customer data
local function TakeOrder(customerData)
  local orderText = ""
  for i, item in ipairs(customerData.order) do
    orderText = orderText .. sharedConfig.Items[item].label .. (i < #customerData.order and ", " or "")
  end

  lib.notify({ title = 'New Order', description = orderText, type = 'info', duration = 10000 })
  TriggerServerEvent('waiter:server:takeOrder', customerData.id)
end

---Deliver food to customer
---@param customerData table Customer data
local function DeliverFood(customerData)
  local tray = GetMyTray()

  -- Match tray items with customer order
  local matchedItems, itemsDelivered = MatchTrayWithOrder(tray, customerData.order)

  -- Tell server to remove delivered items
  if itemsDelivered > 0 then
    for _, item in ipairs(matchedItems) do
      TriggerServerEvent('waiter:server:modifyTray', 'remove', item)
    end

    -- Update server with new order
    TriggerServerEvent('waiter:server:updateCustomerOrder', customerData.id, customerData.order)
  end

  -- Process Results
  if itemsDelivered > 0 then
    if #customerData.order == 0 then
      -- Order Complete
      lib.notify({ type = 'success', description = 'Order Delivered! Customer is happy.' })
      TriggerServerEvent('waiter:pay', itemsDelivered)
      TriggerServerEvent('waiter:server:deliverFood', customerData.id, itemsDelivered)
    else
      -- Partial Delivery
      local remainingStr = ""
      for _, v in pairs(customerData.order) do
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
    for _, v in pairs(customerData.order) do
      orderStr = orderStr .. sharedConfig.Items[v].label .. ", "
    end
    lib.notify({ type = 'error', description = 'Wrong Items! Customer needs: ' .. orderStr })
  end
end

-- Watch for customer statebag changes on ALL entities
AddStateBagChangeHandler('waiterCustomer', nil, function(bagName, _, value, _, replicated)
  if not value then return end

  -- bagName format: "entity:12345"
  local netidStr = bagName:gsub('entity:', '')
  local netid = tonumber(netidStr)
  if not netid then return end

  local ped = NetworkGetEntityFromNetworkId(netid)
  if not DoesEntityExist(ped) then return end

  -- Track this customer
  if not trackedCustomers[netid] then
    trackedCustomers[netid] = { ped = ped, waveThread = nil }
    table.insert(State.allPeds, ped)

    -- Setup ox_target interactions
    exports.ox_target:addLocalEntity(ped, {
      {
        name = 'take_order',
        label = 'Take Order',
        icon = 'fa-solid fa-clipboard',
        distance = 2.0,
        canInteract = function()
          local data = Entity(ped).state.waiterCustomer
          return data and data.status == 'waiting_order'
        end,
        onSelect = function()
          local data = Entity(ped).state.waiterCustomer
          if data then TakeOrder(data) end
        end
      },
      {
        name = 'deliver_food',
        label = 'Deliver Food',
        icon = 'fa-solid fa-utensils',
        distance = 2.0,
        canInteract = function()
          local data = Entity(ped).state.waiterCustomer
          return data and data.status == 'waiting_food'
        end,
        onSelect = function()
          local data = Entity(ped).state.waiterCustomer
          if data then DeliverFood(data) end
        end
      }
    })
  end

  -- Handle status change
  handleCustomerStatus(ped, value)
end)

-- Cleanup when customer entity is deleted
CreateThread(function()
  while true do
    Wait(1000)
    for netid, data in pairs(trackedCustomers) do
      if not DoesEntityExist(data.ped) then
        -- Remove from tracking
        for k, v in pairs(State.allPeds) do
          if v == data.ped then
            table.remove(State.allPeds, k)
            break
          end
        end
        trackedCustomers[netid] = nil
      end
    end
  end
end)
