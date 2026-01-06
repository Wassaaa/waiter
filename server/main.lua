-- Server-side Payment Logic
lib.versionCheck('Wassaaa/waiter')
lib.print.info('Server Started')

local config = require 'config.shared'

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

  -- Check if player has the correct job
  if player.PlayerData.job.name ~= config.JobName then
    return false, 'You must have the waiter job to earn money'
  end

  -- Check if player is on duty (if required)
  if config.RequireOnDuty and not player.PlayerData.job.onduty then
    return false, 'You must be on duty to earn money'
  end

  return true
end

-- Payment Event
---@param itemsDelivered number Number of items delivered to customer
RegisterNetEvent('waiter:pay', function(itemsDelivered)
  local src = source --[[@as number]]

  if not itemsDelivered or itemsDelivered < 1 then return end

  -- Security: Validate player can work
  local canWork, reason = canPlayerWork(src)
  if not canWork then
    exports.qbx_core:Notify(src, reason, 'error')
    return
  end

  local player = exports.qbx_core:GetPlayer(src)
  if not player then return end

  local amount = itemsDelivered * config.PayPerItem

  -- Add money to player
  local success = player.Functions.AddMoney(config.PaymentType, amount, 'waiter-job-payment')

  if success then
    exports.qbx_core:Notify(src, ('Earned $%s for %s items!'):format(amount, itemsDelivered), 'success')
  else
    exports.qbx_core:Notify(src, 'Payment failed!', 'error')
  end
end)

lib.callback.register('waiter:canWork', function(source)
  return canPlayerWork(source)
end)
