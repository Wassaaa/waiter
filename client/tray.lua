-- Tray and Hand Item Management
local config = require 'config.client'
local sharedConfig = require 'config.shared'

function UpdateHandVisuals()
  local ped = PlayerPedId()

  -- Clear existing visuals
  for _, prop in pairs(State.handProps) do SafeDelete(prop) end
  SafeDelete(State.trayProp)
  State.handProps = {}

  -- If hand is empty, stop animation
  if #State.handContent == 0 then
    ClearPedTasks(ped)
    return
  end

  -- 1. Play Animation
  PlayAnimUpper(ped, config.Anims.Tray.dict, config.Anims.Tray.anim, true)

  -- 2. Spawn Tray Prop
  local trayHash = joaat("prop_food_tray_01")
  lib.requestModel(trayHash)
  State.trayProp = CreateObject(trayHash, 0, 0, 0, true, true, false)

  local boneIndex = GetPedBoneIndex(ped, 57005)

  -- Offsets (X, Y, Z) | Rotation (Pitch, Roll, Yaw)
  local x, y, z = 0.1, 0.05, -0.1
  local rx, ry, rz = 190.0, 300.0, 50.0

  AttachEntityToEntity(State.trayProp, ped, boneIndex, x, y, z, rx, ry, rz, true, true, false, true, 1, true)

  -- 3. Spawn Items on Tray
  local offsets = {
    vector3(0.0, 0.12, 0.05),    -- Center Front
    vector3(-0.12, -0.08, 0.05), -- Left Back
    vector3(0.12, -0.08, 0.05)   -- Right Back
  }

  for i, itemName in ipairs(State.handContent) do
    if sharedConfig.Items[itemName] then
      local propName = sharedConfig.Items[itemName].prop
      local hash = joaat(propName)
      lib.requestModel(hash)

      local itemObj = CreateObject(hash, 0, 0, 0, true, true, false)
      local off = offsets[i] or vector3(0, 0, 0)

      AttachEntityToEntity(itemObj, State.trayProp, 0, off.x, off.y, off.z, 0.0, 0.0, 0.0, true, true, false, true, 1,
        true)
      table.insert(State.handProps, itemObj)
    end
  end
end

function ModifyHand(action, item)
  if action == 'add' then
    if #State.handContent >= sharedConfig.MaxHandItems then
      lib.notify({ type = 'error', description = 'Tray is full!' })
      return
    end
    table.insert(State.handContent, item)
    lib.notify({ type = 'success', description = 'Added ' .. sharedConfig.Items[item].label })
  elseif action == 'remove' then
    for i, val in ipairs(State.handContent) do
      if val == item then
        table.remove(State.handContent, i)
        lib.notify({ type = 'info', description = 'Removed ' .. sharedConfig.Items[item].label })
        break
      end
    end
  elseif action == 'clear' then
    State.handContent = {}
    lib.notify({ type = 'info', description = 'Tray cleared' })
  end
  UpdateHandVisuals()
end
