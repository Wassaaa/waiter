-- Shared configuration (used by both client and server)
return {
  -- Locations
  EntranceCoords  = vector4(-1266.05, -891.02, 10.48, 26.34),
  Management      = {
    coords = vector4(-1269.15, -878.01, 10.93, 37.34),
    radius = 1.0,
    target = {
      open = { icon = 'fa-solid fa-door-open', label = 'Open Restaurant' },
      close = { icon = 'fa-solid fa-door-closed', label = 'Close Restaurant' },
    }
  },
  ProximityRadius = 30.0, -- Distance for customer spawning, furniture loading, and prop cleanup

  -- World Props to Delete (models that exist in the world at this location)
  PropsToDelete   = {
    joaat('prop_chair_01a'),
    joaat('prop_table_01'),
  },

  -- Furniture Layout (spawned by server, tracked by client)
  -- Types: 'table', 'chair', 'kitchen'
  -- Kitchen props can have 'items' array to specify which menu items can be picked up from them
  Furniture       = {

    { type = 'table', hash = joaat('prop_table_01'),  coords = vector4(-1267.092, -881.2587, 10.935, 121.6102) },
    { type = 'table', hash = joaat('prop_table_01'),  coords = vector4(-1265.48, -880.2396, 10.935, 34.2938) },
    { type = 'table', hash = joaat('prop_table_01'),  coords = vector4(-1277.4573, -882.4235, 10.935, 310.2459) },
    { type = 'table', hash = joaat('prop_table_01'),  coords = vector4(-1278.5657, -880.8902, 10.935, 35.6781) },
    { type = 'table', hash = joaat('prop_table_01'),  coords = vector4(-1275.7944, -884.8367, 10.935, 38.4381) },
    { type = 'table', hash = joaat('prop_table_01'),  coords = vector4(-1282.6851, -875.8983, 10.935, 308.4373) },
    { type = 'table', hash = joaat('prop_table_01'),  coords = vector4(-1284.2375, -873.7656, 10.935, 35.3706) },

    { type = 'chair', hash = joaat('prop_chair_01a'), coords = vector4(-1276.8093, -883.1454, 10.935, 210.3148) },
    { type = 'chair', hash = joaat('prop_chair_01a'), coords = vector4(-1267.9293, -881.749, 10.935, 115.4048) },
    { type = 'chair', hash = joaat('prop_chair_01a'), coords = vector4(-1276.6741, -881.6671, 10.935, 329.8016) },
    { type = 'chair', hash = joaat('prop_chair_01a'), coords = vector4(-1282.0602, -876.6229, 10.935, 210.2656) },
    { type = 'chair', hash = joaat('prop_chair_01a'), coords = vector4(-1264.7139, -879.6712, 10.935, 296.066) },
    { type = 'chair', hash = joaat('prop_chair_01a'), coords = vector4(-1267.6223, -880.4663, 10.935, 23.3893) },
    { type = 'chair', hash = joaat('prop_chair_01a'), coords = vector4(-1266.0082, -879.4261, 10.935, 28.2371) },
    { type = 'chair', hash = joaat('prop_chair_01a'), coords = vector4(-1279.1121, -880.0884, 10.935, 29.667) },
    { type = 'chair', hash = joaat('prop_chair_01a'), coords = vector4(-1283.3225, -875.1124, 10.935, 29.3791) },
    { type = 'chair', hash = joaat('prop_chair_01a'), coords = vector4(-1276.2147, -883.976, 10.935, 29.8354) },
    { type = 'chair', hash = joaat('prop_chair_01a'), coords = vector4(-1275.2023, -884.0359, 10.935, 309.1954) },
    { type = 'chair', hash = joaat('prop_chair_01a'), coords = vector4(-1283.5686, -874.3913, 10.935, 214.1049) },
    { type = 'chair', hash = joaat('prop_chair_01a'), coords = vector4(-1277.8182, -880.2822, 10.935, 301.0534) },
    { type = 'chair', hash = joaat('prop_chair_01a'), coords = vector4(-1284.7731, -872.9631, 10.935, 29.6095) },

    -- Kitchen Props (type = 'kitchen') - each can serve different items/actions
    -- 'actions' references keys from the Items table below
    {
      type = 'kitchen',
      hash = joaat('prop_bbq_5'),
      coords = vector4(-1273.61, -885.89, 10.93, 310.93),
      actions = { 'burger', 'fries', 'drink', 'coffee', 'clearTray' },
    }
  },

  -- Kitchen Actions
  -- type: 'food' = orderable item with prop, 'utility' = action only (clear tray, etc)
  -- target.action: 'add' (default) adds item to tray, 'clear' clears tray
  -- target.icon/label/distance: ox_target options - all optional with defaults
  -- label: display name (used in notifications, orders) - required for 'food' type
  -- price/prop: required for 'food' type
  -- offset: {x, y, z, rx, ry, rz} adjustments when placed on tray (optional)
  Actions         = {
    burger = {
      type = 'food',
      label = 'Burger',
      price = 25,
      prop = 'prop_cs_burger_01',
      target = { icon = 'fa-solid fa-burger', label = 'Cook Burger' },
      offset = { x = 0.0003, y = 0.0012, z = 0.0235, rx = -3.2, ry = 1.7, rz = -0.1 },
    },
    drink = {
      type = 'food',
      label = 'Drink',
      price = 10,
      prop = 'prop_ecola_can',
      target = { icon = 'fa-solid fa-martini-glass', label = 'Pour Drink' },
      offset = { x = -0.0005, z = 0.0490, rx = -3.2, ry = 1.7, rz = -0.2 },
    },
    fries = {
      type = 'food',
      label = 'Fries',
      price = 15,
      prop = 'prop_food_chips',
      target = { icon = 'fa-solid fa-plus', label = 'Grab Fries' },
      offset = { x = 0.0004, y = 0.0007, z = -0.0156, rz = -0.2 },
    },
    coffee = {
      type = 'food',
      label = 'Coffee',
      price = 15,
      prop = 'prop_food_cb_coffee',
      target = { icon = 'fa-solid fa-coffee', label = 'Get Coffee' },
      offset = { y = 0.0003, z = -0.0077, rx = -3.2, ry = 1.7, rz = -0.3 },
    },
    clearTray = {
      type = 'utility',
      target = { icon = 'fa-solid fa-trash', label = 'Clear Tray', action = 'clear' },
    },
  },

  -- Tray Configuration
  Tray            = {
    prop = 'prop_food_tray_01',
    -- Attachment to player hand (bone 57005 = right hand)
    bone = 57005,
    offset = { x = 0.1, y = 0.05, z = -0.1 },
    rotation = { x = 190.0, y = 300.0, z = 50.0 },

    -- Slot positions on the tray (relative to tray prop)
    -- rx, ry, rz are optional rotation offsets (for edge items to look slanted)
    -- More slots can be unlocked based on skill in future
    slots = {
      { x = 0.1775,  y = 0.0939,  z = 0.0167, rx = 3.2,  ry = -1.7 },
      { x = -0.1600, y = -0.1121, z = 0.0190, rx = -6.0, rz = -1.2 },
      { x = 0.1827,  y = -0.0816, z = 0.0183, rx = -0.1, ry = -0.3, rz = -4.5 },
      { x = -0.1478, y = 0.1142,  z = 0.0221, rx = 12.6, ry = -2.8, rz = 75.2 },
      { x = 0.0060,  y = 0.0592,  z = 0.0156 },
      { x = 0.0027,  y = -0.0930, z = 0.0173, rz = -0.3 },
    },

    -- Default item offset (used if item.offset is missing)
    defaultItemOffset = { x = 0.0, y = 0.0, z = 0.0, rx = 0.0, ry = 0.0, rz = 0.0 },
  },

  -- Defaults for ox_target options (used when item.target.X is missing)
  TargetDefaults  = {
    action = 'add',
    icon = 'fa-solid fa-plus',
    label = 'Pick up %s', -- %s = item label
    distance = 2.0,
  },

  -- Timings (in milliseconds)
  SpawnInterval   = 10000,  -- Time between customer spawns
  WalkTimeout     = 60000,  -- Timeout if customer gets stuck
  PatienceOrder   = 10000,  -- How long customer waits for order to be taken (DEBUG: 10s)
  PatienceFood    = 300000, -- How long customer waits for food delivery (5 minutes)
  EatTime         = 10000,  -- How long customer takes to eat
  WaveIntervalMin = 5000,   -- Min time between waves
  WaveIntervalMax = 10000,  -- Max time between waves
  SitDelay        = 2000,   -- Delay after sitting before waiting for order
  WalkoutTimeout  = 30000,  -- Max time for customer to walk out before forced cleanup
  FadeoutDuration = 1000,   -- Time for customer fadeout (in ms)

  -- Customer Models
  Models          = {
    'a_f_y_hipster_01',
    'a_m_y_business_02',
    'g_m_y_ballasout_01',
    'a_f_m_beach_01',
    'a_m_y_genstreet_01',
    'a_f_y_tourist_01'
  },

  -- Payment Settings
  PayPerItem      = 50,     -- Money earned per item delivered
  PaymentType     = 'cash', -- 'cash' or 'bank'

  -- Job Integration (set JobName to nil to disable job requirement)
  JobName         = 'waiter', -- Set to 'waiter' when you create the job in shared/jobs.lua
  RequireOnDuty   = false,    -- Require player to be on duty to work

  -- Gameplay Limits
  MaxHandItems    = 6, -- Max items on tray at once
  OrderSizeMin    = 1, -- Min items per customer order
  OrderSizeMax    = 3, -- Max items per customer order
}
