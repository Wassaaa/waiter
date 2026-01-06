-- =========================================================
-- 1. CONFIGURATION
-- =========================================================
local Config = {}

-- Locations
Config.EntranceCoords = vector4(-1266.05, -891.02, 10.48, 26.34)
Config.KitchenCoords  = vector4(-1273.61, -885.89, 10.93, 310.93)

Config.Furniture = {
    -- 1
    { type = 'table', hash = joaat('prop_table_01'), coords = vector4(-1267.09, -881.66, 11.329, 121.61) },
    { type = 'chair', hash = joaat('prop_chair_01a'), coords = vector4(-1268.32, -882.15, 10.94, 115.4) },
    { type = 'chair', hash = joaat('prop_chair_01a'), coords = vector4(-1267.62, -880.47, 10.94, 23.39) },
    -- 2
    { type = 'table', hash = joaat('prop_table_01'), coords = vector4(-1265.67, -880.34, 11.329, 34.29) },
    { type = 'chair', hash = joaat('prop_chair_01a'), coords = vector4(-1266.21, -879.23, 10.94, 28.24) },
    { type = 'chair', hash = joaat('prop_chair_01a'), coords = vector4(-1264.71, -879.67, 10.94, 296.07) },
    -- 3
    { type = 'chair', hash = joaat('prop_chair_01a'), coords = vector4(-1276.19, -883.99, 10.94, 29.11) },
    { type = 'table', hash = joaat('prop_table_01'), coords = vector4(-1275.65, -884.78, 11.32, 35.15) },
    { type = 'chair', hash = joaat('prop_chair_01a'), coords = vector4(-1274.89, -884.21, 10.93, 297.05) },
    -- 4
    { type = 'table', hash = joaat('prop_table_01'), coords = vector4(-1277.42, -882.41, 11.33, 308.58) },
    { type = 'chair', hash = joaat('prop_chair_01a'), coords = vector4(-1276.66, -881.84, 10.94, 302.23) },
    { type = 'chair', hash = joaat('prop_chair_01a'), coords = vector4(-1276.78, -883.16, 10.94, 213.99) },
    -- 5
    { type = 'chair', hash = joaat('prop_chair_01a'), coords = vector4(-1277.84, -880.27, 10.94, 300.19) },
    { type = 'chair', hash = joaat('prop_chair_01a'), coords = vector4(-1279.11, -880.09, 10.93, 29.67) },
    { type = 'table', hash = joaat('prop_table_01'), coords = vector4(-1278.56, -880.88, 11.32, 36.02) },
}

Config.KitchenGrill = {type = 'kitchen', hash = joaat('prop_bbq_5'), coords = Config.KitchenCoords}

-- Menu Items
Config.Items = {
    burger = { label = 'Burger', price = 25, prop = 'prop_cs_burger_01' },
    drink  = { label = 'Drink',  price = 10, prop = 'prop_ecola_can' },
    fries  = { label = 'Fries',  price = 15, prop = 'prop_food_chips' }
}

-- Settings
Config.SpawnInterval    = 10000     -- New customer every 60s
Config.WalkTimeout      = 60000     -- Stuck timeout
-- Config.PatienceOrder    = 300000    -- 5 mins to take order
Config.PatienceOrder    = 10000
Config.PatienceFood     = 300000    -- 5 mins to deliver food
Config.PayPerItem       = 50        -- Tip/Payment amount
Config.MaxHandItems     = 3         -- Max items on tray

Config.WaveIntervalMin  = 5000      -- Min time to wait for waving
Config.WaveIntervalMax  = 10000     -- Max time to wait for waving

Config.EatTime          = 10000     -- Time for customer to eat at the table

Config.Models = {
    'a_f_y_hipster_01', 'a_m_y_business_02', 'g_m_y_ballasout_01', 'a_f_m_beach_01', 
    'a_m_y_genstreet_01', 'a_f_y_tourist_01'
}

Config.Anims = {
    Wave  = { dict = "friends@frj@ig_1", anim = "wave_a" },
    Anger = { dict = "melee@unarmed@streamed_core", anim = "light_punch_a" },
    Eat   = { dict = "mp_player_inteat@burger", anim = "mp_player_int_eat_burger_fp" },
    Tray  = { dict = "amb@world_human_leaning@female@wall@back@hand_up@idle_a", anim = "idle_a" }
}

-- =========================================================
-- 2. STATE MANAGEMENT
-- =========================================================
local State = {
    spawnedProps = {},      -- Furniture objects
    validSeats = {},        -- Logic for seats
    customers = {},         -- Active customer logic
    allPeds = {},           -- All peds created (for reliable cleanup)
    handContent = {},       -- Items currently in hand: { 'burger', 'drink' }
    handProps = {},         -- Visual props attached to player
    trayProp = nil,         -- The main tray object
    kitchenGrill = nil,     -- The kitchen grill prop
    isRestaurantOpen = false
}

-- =========================================================
-- 3. UTILITY FUNCTIONS
-- =========================================================

local function PlayAnimUpper(ped, dict, anim, loop)
    if not DoesEntityExist(ped) then return end
    local flag = 48  -- Upper body only
    local duration = 3000
    if loop then 
        flag = 49  -- 48 + 1 = Upper body + Loop
        duration = -1  -- Indefinite when looping
    end
    lib.requestAnimDict(dict)
    TaskPlayAnim(ped, dict, anim, 8.0, -8.0, duration, flag, 0, false, false, false)
end

-- Used to safely delete peds/props
local function SafeDelete(entity)
    if DoesEntityExist(entity) then DeleteEntity(entity) end
end

local function CleanupScene()
    -- 1. Delete Furniture
    for _, prop in pairs(State.spawnedProps) do SafeDelete(prop) end
    
    -- 2. Delete All Peds (Leaving or Sitting)
    for _, ped in pairs(State.allPeds) do SafeDelete(ped) end

    -- 3. Delete Hand/Tray Props
    for _, prop in pairs(State.handProps) do SafeDelete(prop) end
    SafeDelete(State.trayProp)
    
    -- 4. Reset Logic
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

-- =========================================================
-- 4. HAND & TRAY SYSTEM
-- =========================================================

local function UpdateHandVisuals()
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
    PlayAnimUpper(ped, Config.Anims.Tray.dict, Config.Anims.Tray.anim, true)
    
    -- 2. Spawn Tray Prop
    local trayHash = joaat("prop_food_tray_01")
    lib.requestModel(trayHash)
    State.trayProp = CreateObject(trayHash, 0, 0, 0, true, true, false)

    local boneIndex = GetPedBoneIndex(ped, 57005)
    
    -- Offsets (X, Y, Z) | Rotation (Pitch, Roll, Yaw)
    local x, y, z = 0.1, 0.05, -0.1
    local rx, ry, rz = 190.0, 300.0, 50.0

    AttachEntityToEntity(State.trayProp, ped, boneIndex,
        x, y, z, 
        rx, ry, rz, 
        true, true, false, true, 1, true
    )

    -- 3. Spawn Items on Tray
    local offsets = {
        vector3(0.0, 0.12, 0.05),   -- Center Front
        vector3(-0.12, -0.08, 0.05), -- Left Back
        vector3(0.12, -0.08, 0.05)   -- Right Back
    }

    for i, itemName in ipairs(State.handContent) do
        if Config.Items[itemName] then
            local propName = Config.Items[itemName].prop
            local hash = joaat(propName)
            lib.requestModel(hash)
            
            local itemObj = CreateObject(hash, 0, 0, 0, true, true, false)
            local off = offsets[i] or vector3(0,0,0)
            
            AttachEntityToEntity(itemObj, State.trayProp, 0, off.x, off.y, off.z, 0.0, 0.0, 0.0, true, true, false, true, 1, true)
            table.insert(State.handProps, itemObj)
        end
    end
end

local function ModifyHand(action, item)
    if action == 'add' then
        if #State.handContent >= Config.MaxHandItems then
            lib.notify({ type = 'error', description = 'Tray is full!' })
            return
        end
        table.insert(State.handContent, item)
        lib.notify({ type = 'success', description = 'Added '..Config.Items[item].label })
    elseif action == 'remove' then
        -- Remove the specific item type if found
        for i, val in ipairs(State.handContent) do
            if val == item then
                table.remove(State.handContent, i)
                lib.notify({ type = 'info', description = 'Removed '..Config.Items[item].label })
                break
            end
        end
    elseif action == 'clear' then
        State.handContent = {}
        lib.notify({ type = 'info', description = 'Tray cleared' })
    end
    UpdateHandVisuals()
end

-- =========================================================
-- 5. CUSTOMER LOGIC
-- =========================================================

local function CustomerLeave(customer, reason)
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

    -- Re-apply ghosting through all furniture when leaving (in case collision was restored)
    for _, prop in pairs(State.spawnedProps) do
        if DoesEntityExist(prop) then 
            SetEntityNoCollisionEntity(prop, ped, false)
        end
    end
    
    -- Walk to exit
    ClearPedTasksImmediately(ped)
    TaskGoToCoordAnyMeans(ped, Config.EntranceCoords.x, Config.EntranceCoords.y, Config.EntranceCoords.z, 1.0, 0, false, 786603, 0xbf800000)
    -- Final Delete
    SetTimeout(10000, function()
        if DoesEntityExist(ped) then
            for i = 255, 0, -50 do SetEntityAlpha(ped, i, false) Wait(50) end
            SafeDelete(ped)
            for k, v in pairs(State.allPeds) do if v == ped then table.remove(State.allPeds, k) break end end
        end
    end)

    -- Remove from active customer logic list
    for k, v in pairs(State.customers) do if v == customer then table.remove(State.customers, k) break end end
end

local function StartCustomerLogic(customer)
    CreateThread(function()
        local seat = State.validSeats[customer.seatId]
        if not seat then SafeDelete(customer.ped) return end
        
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
        TaskStartScenarioAtPosition(ped, "PROP_HUMAN_SEAT_CHAIR", seat.coords.x, seat.coords.y, seat.coords.z + 0.50, seatH, -1, true, true)
        
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

local function DeliverFood(customer)
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

    -- 2. PROCESS RESULTS
    if itemsDelivered > 0 then
        UpdateHandVisuals()
        
        if #customer.order == 0 then
            -- === ORDER COMPLETE ===
            customer.status = "eating"
            lib.notify({ type = 'success', description = 'Order Delivered! Customer is happy.' })
            
            -- Payment Trigger (Example)
            -- TriggerServerEvent('waiter:pay', itemsDelivered * Config.PayPerItem) 
            
            -- Play eating animation with proper looping
            PlayAnimUpper(ped, Config.Anims.Eat.dict, Config.Anims.Eat.anim, true)
            Wait(Config.EatTime)
            
            CustomerLeave(customer, "happy")
        else
            -- === PARTIAL DELIVERY ===
            -- Build a string of what is left
            local remainingStr = ""
            for _, v in pairs(customer.order) do 
                remainingStr = remainingStr .. Config.Items[v].label .. ", " 
            end

            lib.notify({ 
                type = 'info', 
                title = 'Partial Delivery',
                description = 'Gave '..itemsDelivered..' item(s).\nStill needs: ' .. remainingStr 
            })
        end
    else
        -- === NO MATCHES ===
        local orderStr = ""
        for _, v in pairs(customer.order) do 
            orderStr = orderStr .. Config.Items[v].label .. ", " 
        end
        lib.notify({ type = 'error', description = 'Wrong Items! Customer needs: ' .. orderStr })
    end
end

local function SpawnSingleCustomer()
    local seat = nil
    for _, s in ipairs(State.validSeats) do if not s.isOccupied then seat = s break end end
    if not seat then return end

    local model = Config.Models[math.random(1, #Config.Models)]
    lib.requestModel(model)
    local ped = CreatePed(4, joaat(model), Config.EntranceCoords.x, Config.EntranceCoords.y, Config.EntranceCoords.z, Config.EntranceCoords.w, true, false)
    
    -- Make customer ghost through chairs only (not tables) from the start
    for _, prop in pairs(State.spawnedProps) do
        if DoesEntityExist(prop) then
            SetEntityNoCollisionEntity(prop, ped, false)
        end
    end
    
    seat.isOccupied = true
    table.insert(State.allPeds, ped) -- Add to cleanup list

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
                -- Generate Random Order (1 to 3 items)
                local itemCount = math.random(1, Config.MaxHandItems)
                local itemKeys = {'burger', 'drink', 'fries'}
                local orderText = ""
                
                for i=1, itemCount do
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

-- =========================================================
-- 6. KITCHEN SETUP
-- =========================================================

local function SetupKitchen()
    local options = {}
    
    -- Generate Add Options
    for k, v in pairs(Config.Items) do
        table.insert(options, {
            name = 'add_'..k,
            icon = 'fa-solid fa-plus',
            label = 'Pick up ' .. v.label,
            distance = 2.0,
            onSelect = function() ModifyHand('add', k) end
        })
    end
    
    -- Generate Remove Options (Generic clear or specific removal)
    table.insert(options, {
        name = 'clear_tray',
        icon = 'fa-solid fa-trash',
        label = 'Clear Tray',
        distance = 2.0,
        onSelect = function() ModifyHand('clear') end
    })

    -- Spawn Grill
    local cooker = Config.KitchenGrill
    lib.requestModel(cooker.hash)
    local grill = CreateObject(cooker.hash, cooker.coords.x, cooker.coords.y, cooker.coords.z, false, false, false)
    PlaceObjectOnGroundProperly(grill)
    SetEntityHeading(grill, cooker.coords.w)
    FreezeEntityPosition(grill, true)
    table.insert(State.spawnedProps, grill)
    
    -- Attach options to the grill entity
    exports.ox_target:addLocalEntity(grill, options)
    State.kitchenGrill = grill
end

local function DeleteWorldProps()
    -- Only delete specific prop models that we're replacing (chairs and tables)
    local propsToDelete = {
        joaat('prop_chair_01a'),
        joaat('prop_table_01')
    }
    
    for _, item in ipairs(Config.Furniture) do
        local existingProp = GetClosestObjectOfType(item.coords.x, item.coords.y, item.coords.z, 0.5, item.hash, false, false, false)
        
        while DoesEntityExist(existingProp) do
            local propModel = GetEntityModel(existingProp)
            
            -- Only delete if:
            -- 1. It matches one of our furniture models
            -- 2. It's NOT one of our spawned props
            local isTargetModel = false
            for _, modelHash in ipairs(propsToDelete) do
                if propModel == modelHash then
                    isTargetModel = true
                    break
                end
            end
            
            local isOurProp = false
            for _, ourProp in pairs(State.spawnedProps) do
                if existingProp == ourProp then
                    isOurProp = true
                    break
                end
            end
            
            if isTargetModel and not isOurProp then
                SetEntityAsMissionEntity(existingProp, true, true)
                DeleteObject(existingProp)
            else
                break
            end
            
            existingProp = GetClosestObjectOfType(item.coords.x, item.coords.y, item.coords.z, 0.5, item.hash, false, false, false)
        end
    end
end

local function SetupRestaurant()
    CleanupScene()
    
    -- Initial cleanup of world props
    DeleteWorldProps()
    
    -- Spawn Furniture
    for i, item in ipairs(Config.Furniture) do
        lib.requestModel(item.hash)
        local obj = CreateObject(item.hash, item.coords.x, item.coords.y, item.coords.z, false, false, false)
        PlaceObjectOnGroundProperly(obj)
        SetEntityHeading(obj, item.coords.w)
        FreezeEntityPosition(obj, true)
        table.insert(State.spawnedProps, obj)

        if item.type == 'chair' then
            local finalCoords = GetEntityCoords(obj)
            -- Use array size for ID
            local newId = #State.validSeats + 1
            table.insert(State.validSeats, {
                entity = obj,
                coords = vector4(finalCoords.x, finalCoords.y, finalCoords.z, item.coords.w),
                isOccupied = false,
                id = newId
            })
        end
    end

    SetupKitchen()
    State.isRestaurantOpen = true
    print("^2[Waiter Job] Restaurant Open! Seats: " .. #State.validSeats .. "^7")

    -- Thread: Keep world props deleted
    CreateThread(function()
        while State.isRestaurantOpen do
            DeleteWorldProps()
            Wait(5000)
        end
    end)

    -- Thread: Spawn customers
    CreateThread(function()
        Wait(2000) 
        if State.isRestaurantOpen then SpawnSingleCustomer() end

        while State.isRestaurantOpen do
            Wait(Config.SpawnInterval)
            if State.isRestaurantOpen then SpawnSingleCustomer() end
        end
    end)
end

-- =========================================================
-- COMMANDS & EVENTS
-- =========================================================

RegisterCommand('setuprest', function() SetupRestaurant() end)

RegisterCommand('newcustomer', function() SpawnSingleCustomer() end)

RegisterCommand('closerest', function()
    CleanupScene()
    lib.notify({ type = 'info', description = 'Restaurant Closed' })
end)

AddEventHandler('onResourceStop', function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then return end
    CleanupScene()
    ModifyHand('clear') -- Ensure player hands are empty
end)


-- Usage: /tunetray 0.1 0.05 -0.1 180.0 180.0 0.0
RegisterCommand('tunetray', function(source, args)
    if not State.trayProp or not DoesEntityExist(State.trayProp) then return end
    
    local x = tonumber(args[1]) or 0.1
    local y = tonumber(args[2]) or 0.05
    local z = tonumber(args[3]) or -0.1
    local rx = tonumber(args[4]) or 180.0
    local ry = tonumber(args[5]) or 180.0
    local rz = tonumber(args[6]) or 0.0
    
    AttachEntityToEntity(State.trayProp, PlayerPedId(), GetPedBoneIndex(PlayerPedId(), 57005), x, y, z, rx, ry, rz, true, true, false, true, 1, true)
    print(string.format("Adjusted: %.2f %.2f %.2f | %.2f %.2f %.2f", x, y, z, rx, ry, rz))
end)

CreateThread(function()
    -- Wait 1 second to ensure everything is loaded
    Wait(1000) 
    
    -- Automatically set up the restaurant
    print("^3[Dev] Auto-Starting Restaurant Setup...^7")
    SetupRestaurant()
end)
