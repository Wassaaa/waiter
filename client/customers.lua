-- Customer Management - Client Side (Statebag-driven)
local clientConfig = require 'config.client'
local sharedConfig = require 'config.shared'

-- Track customer peds and their wave timing
local trackedCustomers = {} -- [netid] = { ped, nextWaveTime }

-- Helper alias for consistency/simplicity in this file
local IsWaiter = State.IsWaiter

-- Helper for robust pathfinding (handles stuck peds)
local function SmartWalkTo(ped, x, y, z, options)
  options = options or {}
  local distThreshold = options.threshold or 1.0
  local timeout = options.timeout or sharedConfig.WalkTimeout
  local onArrive = options.onArrive

  TaskGoToCoordAnyMeans(ped, x, y, z, 1.0, 0, false, 786603, 0xbf800000)

  CreateThread(function()
    local walkStart = GetGameTimer()
    local lastPos = GetEntityCoords(ped)
    local stuckDuration = 0

    while DoesEntityExist(ped) do
      local currentPos = GetEntityCoords(ped)
      local dist = #(currentPos - vector3(x, y, z))

      -- Success
      if dist <= distThreshold then
        if onArrive then onArrive() end
        break
      end

      -- Timeout
      if (GetGameTimer() - walkStart) > timeout then
        break
      end

      -- Stuck Check
      if #(currentPos - lastPos) < 0.2 then
        stuckDuration = stuckDuration + 500
        if stuckDuration >= 3000 then -- 3s Stuck
          ClearPedTasks(ped)
          Wait(100)
          TaskGoToCoordAnyMeans(ped, x, y, z, 1.0, 0, false, 786603, 0xbf800000)
          stuckDuration = 0
          walkStart = GetGameTimer() -- Reset timeout
        end
      else
        stuckDuration = 0
        lastPos = currentPos
      end

      Wait(500)
    end
  end)
end

---Handle customer status changes via statebag
---@param ped number The ped entity
---@param customerData table Customer data from statebag
local function handleCustomerStatus(ped, customerData)
  if not DoesEntityExist(ped) then return end

  local status = customerData.status
  local seatCoords = customerData.seatCoords

  if status == 'walking_in' then
    -- Walk to seat using smart helper
    SmartWalkTo(ped, seatCoords.x, seatCoords.y, seatCoords.z, {
      threshold = 1.7,
      onArrive = function()
        TriggerServerEvent('waiter:server:customerArrived', customerData.id)
      end
    })
  elseif status == 'sitting' then
    -- Sit down
    ClearPedTasks(ped)
    local seatH = (seatCoords.w + 180.0) % 360.0
    TaskStartScenarioAtPosition(ped, "PROP_HUMAN_SEAT_CHAIR", seatCoords.x, seatCoords.y, seatCoords.z + 0.50, seatH, -1,
      true, true)
  elseif status == 'waiting_order' then
    -- Initialize wave timing (handled by centralized thread)
    local netid = customerData.netid
    if not trackedCustomers[netid].nextWaveTime then
      trackedCustomers[netid].nextWaveTime = GetGameTimer() +
          math.random(sharedConfig.WaveIntervalMin, sharedConfig.WaveIntervalMax)
    end
  elseif status == 'eating' then
    -- Play eating animation
    local anim = Utils.GetRandom(clientConfig.Anims.Eat)
    if anim then
      Utils.PlayAnimUpper(ped, anim.dict, anim.anim, true)
    end
  elseif status == 'leaving_angry' or status == 'leaving_happy' then
    -- Handle specific angry behavior
    if status == 'leaving_angry' then
      if IsWaiter() then
        lib.notify({ type = 'warning', description = 'Customer left angry!' })
      end
      local anim = Utils.GetRandom(clientConfig.Anims.Anger)
      if anim then
        Utils.PlayAnimUpper(ped, anim.dict, anim.anim)
      end
      Wait(1500)
    end

    -- Shared exit logic
    ClearPedTasksImmediately(ped)

    local exit = Utils.GetRandom(sharedConfig.Exits)
    if not exit then return end

    SmartWalkTo(ped, exit.x, exit.y, exit.z, {
      threshold = 2.0,
      onArrive = function()
        -- Reached exit, fade out
        for i = 255, 0, -50 do
          SetEntityAlpha(ped, i, false)
          Wait(sharedConfig.FadeoutDuration / 6)
        end
        TriggerServerEvent('waiter:server:customerExited', customerData.id)
      end
    })
  end
end

---Take customer order
---@param customerData table Customer data
local function TakeOrder(customerData)
  local orderText = ""
  for i, item in ipairs(customerData.order) do
    orderText = orderText .. sharedConfig.Items[item].label .. (i < #customerData.order and ", " or "")
  end

  if IsWaiter() then
    lib.notify({ title = 'New Order', description = orderText, type = 'info', duration = 10000 })
  end
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

      -- Remove from local order list (first match only)
      for i, orderKey in ipairs(customerData.order) do
        if orderKey == item.key then
          table.remove(customerData.order, i)
          break
        end
      end
    end

    -- Update server with new order
    TriggerServerEvent('waiter:server:updateCustomerOrder', customerData.id, customerData.order)
  end

  -- Process Results
  if not IsWaiter() then return end

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

  if not NetworkDoesNetworkIdExist(netid) then return end
  local ped = NetworkGetEntityFromNetworkId(netid)
  if not DoesEntityExist(ped) then return end

  -- Track this customer
  if not trackedCustomers[netid] then
    trackedCustomers[netid] = { ped = ped, nextWaveTime = nil }

    -- Setup Ped Flags
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedConfigFlag(ped, 185, true) -- CPED_CONFIG_FLAG_PreventAllMeleeTaunts
    SetPedConfigFlag(ped, 422, true) -- CPED_CONFIG_FLAG_IgnoreBeingOnFire
    SetPedCanPlayAmbientAnims(ped, false)
    SetPedCanPlayAmbientBaseAnims(ped, false)

    -- Setup ox_target interactions
    exports.ox_target:addLocalEntity(ped, {
      {
        name = 'take_order',
        label = 'Take Order',
        icon = 'fa-solid fa-clipboard',
        distance = 2.0,
        canInteract = function()
          if not IsWaiter() then return false end
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
          if not IsWaiter() then return false end
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

-- Centralized customer management thread
CreateThread(function()
  while true do
    Wait(1000)
    for netid, data in pairs(trackedCustomers) do
      -- Cleanup deleted entities
      if not DoesEntityExist(data.ped) then
        trackedCustomers[netid] = nil
      else
        -- Handle wave animations for waiting customers
        local customerData = Entity(data.ped).state.waiterCustomer
        if customerData and customerData.status == 'waiting_order' then
          if data.nextWaveTime and GetGameTimer() >= data.nextWaveTime then
            local anim = Utils.GetRandom(clientConfig.Anims.Wave)
            if anim then
              Utils.PlayAnimUpper(data.ped, anim.dict, anim.anim)
            end
            data.nextWaveTime = GetGameTimer() + math.random(sharedConfig.WaveIntervalMin, sharedConfig.WaveIntervalMax)
          end
        end
      end
    end
  end
end)
