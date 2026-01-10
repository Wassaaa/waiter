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

---@param itemsDelivered number Number of items delivered to customer
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

  local amount = itemsDelivered * config.PayPerItem
  local success = player.Functions.AddMoney(config.PaymentType, amount, 'waiter-job-payment')

  if success then
    exports.qbx_core:Notify(src, ('Earned $%s for %s items!'):format(amount, itemsDelivered), 'success')
  else
    exports.qbx_core:Notify(src, 'Payment failed!', 'error')
  end
end)

---@param action string 'add', 'remove', or 'clear'
---@param item string? Item name (for add/remove)
RegisterNetEvent('waiter:server:modifyTray', function(action, item)
  local src = source --[[@as number]]
  local tray = Player(src).state.waiterTray or {}

  if action == 'add' then
    local actionData = item and config.Actions[item]
    if not actionData or actionData.type ~= 'food' then
      return exports.qbx_core:Notify(src, 'Invalid item', 'error')
    end

    if #tray >= config.MaxHandItems then
      return exports.qbx_core:Notify(src, 'Tray is full!', 'error')
    end

    table.insert(tray, item)
    exports.qbx_core:Notify(src, ('Added %s'):format(actionData.label), 'success')
  elseif action == 'remove' then
    if not item then return end

    for i, val in ipairs(tray) do
      if val == item then
        table.remove(tray, i)
        local actionData = config.Actions[val]
        exports.qbx_core:Notify(src, ('Removed %s'):format(actionData and actionData.label or val), 'info')
        break
      end
    end
  elseif action == 'clear' then
    tray = {}
    exports.qbx_core:Notify(src, 'Tray cleared', 'info')
  end

  Player(src).state:set('waiterTray', tray, true)
end)

-- Callbacks
lib.callback.register('waiter:canWork', function(source)
  return canPlayerWork(source)
end)
