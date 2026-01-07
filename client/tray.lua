function ModifyHand(action, item)
  TriggerServerEvent('waiter:server:modifyTray', action, item)
end

-- Helper to get current tray contents (from statebag)
function GetMyTray()
  return LocalPlayer.state.waiterTray or {}
end

---Match tray items with customer order
---@param tray table Current tray items
---@param order table Customer order (will be modified)
---@return table matched Items that matched the order
---@return number count Number of matches
function MatchTrayWithOrder(tray, order)
  local matched = {}
  
  -- Loop backwards through tray
  for i = #tray, 1, -1 do
    local heldItem = tray[i]
    
    -- Check if customer needs this specific item
    for orderIdx, neededItem in ipairs(order) do
      if neededItem == heldItem then
        table.remove(order, orderIdx)
        table.insert(matched, heldItem)
        break
      end
    end
  end
  
  return matched, #matched
end
