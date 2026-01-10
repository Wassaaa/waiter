Utils = {}

---Get a random item from a list
---@generic T
---@param list T[]
---@return T|nil
function Utils.GetRandom(list)
    if not list or #list == 0 then return nil end
    return list[math.random(#list)]
end

-- Client-side only utilities (IsDuplicityVersion() returns false on client)
if not IsDuplicityVersion() then
    ---Play an upper body animation
    ---@param ped number
    ---@param dict string
    ---@param anim string
    ---@param loop? boolean
    function Utils.PlayAnimUpper(ped, dict, anim, loop)
        if not DoesEntityExist(ped) then return end
        local flag = 48 -- Upper body only
        local duration = 3000
        if loop then
            flag = 49     -- 48 + 1 = Upper body + Loop
            duration = -1 -- Indefinite when looping
        end
        lib.requestAnimDict(dict)
        TaskPlayAnim(ped, dict, anim, 8.0, -8.0, duration, flag, 0, false, false, false)
    end
end
