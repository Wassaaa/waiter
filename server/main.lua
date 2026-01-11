-- Waiter Job - Server Main
lib.versionCheck('Wassaaa/waiter')

local config = require 'config.shared'

-- Functions
---@param source number Player source
---@return boolean canWork Whether player can work
---@return string? reason Reason if they can't work
local function canPlayerWork(source)
  if not config.JobName then
    return true -- No job requirement
  end

  local player = exports.qbx_core:GetPlayer(source)
  if not player then
    return false, 'Player not found'
  end

  if player.PlayerData.job.name ~= config.JobName then
    return false, 'You must have the waiter job to earn money'
  end

  if config.RequireOnDuty and not player.PlayerData.job.onduty then
    return false, 'You must be on duty to earn money'
  end

  return true
end

-- Initialize Global State
GlobalState.WaiterOpen = false

-- Cleanup state on resource start (fixes state persistence on restart)
AddEventHandler('onResourceStart', function(resource)
  if resource ~= GetCurrentResourceName() then return end

  -- Clear GlobalState
  GlobalState.WaiterOpen = false

  -- Set Log Level
  if config.LogLevel then
    local convarName = 'ox:printlevel:' .. GetCurrentResourceName()
    SetConvarReplicated(convarName, config.LogLevel)
    lib.print.debug('Log Level set to:', config.LogLevel)
  end

  -- Clear Player States
  local players = GetPlayers()
  for _, src in ipairs(players) do
    local pState = Player(src).state
    if pState.waiterTray then
      pState:set('waiterTray', {}, true)
    end
  end
end)

---Toggle restaurant state
RegisterNetEvent('waiter:server:toggleRestaurant', function()
  local src = source --[[@as number]]
  local canWork, reason = canPlayerWork(src)
  if not canWork then
    return exports.qbx_core:Notify(src, reason, 'error')
  end

  if GlobalState.WaiterOpen then
    -- Close it
    GlobalState.WaiterOpen = false
    ServerCustomers.Cleanup()
    ServerFurniture.Cleanup()
    exports.qbx_core:Notify(src, 'Restaurant closed', 'success')
  else
    -- Open it
    GlobalState.WaiterOpen = true
    local success = ServerFurniture.Setup()
    if success then
      ServerCustomers.StartSpawning()
      exports.qbx_core:Notify(src, 'Restaurant opened', 'success')
    else
      exports.qbx_core:Notify(src, 'Failed to open restaurant', 'error')
      GlobalState.WaiterOpen = false
    end
  end
end)

---@param itemsDelivered number Number of items delivered to customer (unused for calculation now)
RegisterNetEvent('waiter:pay', function(itemsDelivered)
  local src = source --[[@as number]]

  if not itemsDelivered or itemsDelivered < 1 then return end

  local canWork, reason = canPlayerWork(src)
  if not canWork then
    exports.qbx_core:Notify(src, reason, 'error')
    return
  end

  local player = exports.qbx_core:GetPlayer(src)
  if not player then return end

  -- Calculate Tip based on Job Grade Payment
  -- Default to config.PayPerItem if job payment is missing or 0 (e.g. unemployed/side job)
  local basePay = player.PlayerData.job.payment
  if not basePay or basePay == 0 then
    basePay = config.PayPerItem
  end

  -- Random variation: +/- 20%
  local multiplier = math.random(80, 120) / 100.0
  local amount = math.floor(basePay * multiplier)

  local success = player.Functions.AddMoney(config.PaymentType, amount, 'waiter-job-payment')

  if success then
    exports.qbx_core:Notify(src, ('Received $%s in tips!'):format(amount), 'success')
  else
    exports.qbx_core:Notify(src, 'Payment failed!', 'error')
  end
end)

RegisterNetEvent('waiter:server:modifyTray', function(action, item)
  local src = source --[[@as number]]
  if action == 'add' then
    ServerTray.Add(src, item)
  elseif action == 'remove' then
    ServerTray.Remove(src, item)
  elseif action == 'clear' then
    ServerTray.Clear(src)
  elseif action == 'set' then
    ServerTray.Set(src, item)
  end
end)

-- Callbacks
lib.callback.register('waiter:canWork', function(source)
  return canPlayerWork(source)
end)
