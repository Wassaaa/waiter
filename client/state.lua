-- Shared state management
State = {
  spawnedProps = {},
  validSeats = {},
  customers = {},
  allPeds = {},
  handContent = {},
  handProps = {},
  trayProp = nil,
  kitchenGrill = nil,
  isRestaurantOpen = false
}

-- Utility Functions
function SafeDelete(entity)
  if DoesEntityExist(entity) then DeleteEntity(entity) end
end

function PlayAnimUpper(ped, dict, anim, loop)
  if not DoesEntityExist(ped) then return end
  local flag = 48   -- Upper body only
  local duration = 3000
  if loop then
    flag = 49         -- 48 + 1 = Upper body + Loop
    duration = -1     -- Indefinite when looping
  end
  lib.requestAnimDict(dict)
  TaskPlayAnim(ped, dict, anim, 8.0, -8.0, duration, flag, 0, false, false, false)
end

function CleanupScene()
  -- Delete Furniture
  for _, prop in pairs(State.spawnedProps) do SafeDelete(prop) end

  -- Delete All Peds
  for _, ped in pairs(State.allPeds) do SafeDelete(ped) end

  -- Delete Hand/Tray Props
  for _, prop in pairs(State.handProps) do SafeDelete(prop) end
  SafeDelete(State.trayProp)

  -- Reset Logic
  State.spawnedProps = {}
  State.validSeats = {}
  State.customers = {}
  State.allPeds = {}
  State.handContent = {}
  State.handProps = {}
  State.trayProp = nil
  State.isRestaurantOpen = false
  State.kitchenGrill = nil
end
