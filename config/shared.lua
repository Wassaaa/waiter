-- Shared configuration (used by both client and server)
return {
  -- Locations
  EntranceCoords   = vector4(-1266.05, -891.02, 10.48, 26.34),
  ManagementCoords = vector4(-1269.15, -878.01, 10.93, 37.34),   -- Where to open/close restaurant
  ProximityRadius  = 30.0,                                       -- Distance for customer spawning, furniture loading, and prop cleanup

  -- World Props to Delete (models that exist in the world at this location)
  PropsToDelete    = {
    joaat('prop_chair_01a'),
    joaat('prop_table_01'),
  },

  -- Furniture Layout (spawned by server, tracked by client)
  -- Types: 'table', 'chair', 'kitchen'
  -- Kitchen props can have 'items' array to specify which menu items can be picked up from them
  Furniture        = {
    -- Tables (type = 'table')
    { type = 'table', hash = joaat('prop_table_01'),  coords = vector4(-1267.09, -881.66, 10.94, 121.61) },
    { type = 'table', hash = joaat('prop_table_01'),  coords = vector4(-1265.67, -880.34, 10.94, 34.29) },
    { type = 'table', hash = joaat('prop_table_01'),  coords = vector4(-1275.65, -884.78, 10.94, 35.15) },
    { type = 'table', hash = joaat('prop_table_01'),  coords = vector4(-1277.42, -882.41, 10.94, 308.58) },
    { type = 'table', hash = joaat('prop_table_01'),  coords = vector4(-1278.56, -880.88, 10.94, 36.02) },

    -- Chairs (type = 'chair') - these become valid seats for customers
    { type = 'chair', hash = joaat('prop_chair_01a'), coords = vector4(-1268.32, -882.15, 10.94, 115.4) },
    { type = 'chair', hash = joaat('prop_chair_01a'), coords = vector4(-1267.62, -880.47, 10.94, 23.39) },
    { type = 'chair', hash = joaat('prop_chair_01a'), coords = vector4(-1266.21, -879.23, 10.94, 28.24) },
    { type = 'chair', hash = joaat('prop_chair_01a'), coords = vector4(-1264.71, -879.67, 10.94, 296.07) },
    { type = 'chair', hash = joaat('prop_chair_01a'), coords = vector4(-1276.19, -883.99, 10.94, 29.11) },
    { type = 'chair', hash = joaat('prop_chair_01a'), coords = vector4(-1274.89, -884.21, 10.93, 297.05) },
    { type = 'chair', hash = joaat('prop_chair_01a'), coords = vector4(-1276.66, -881.84, 10.94, 302.23) },
    { type = 'chair', hash = joaat('prop_chair_01a'), coords = vector4(-1276.78, -883.16, 10.94, 213.99) },
    { type = 'chair', hash = joaat('prop_chair_01a'), coords = vector4(-1277.84, -880.27, 10.94, 300.19) },
    { type = 'chair', hash = joaat('prop_chair_01a'), coords = vector4(-1279.11, -880.09, 10.93, 29.67) },

    -- Kitchen Props (type = 'kitchen') - each can serve different items/actions
    -- 'actions' references keys from the Items table below
    {
      type = 'kitchen',
      hash = joaat('prop_bbq_5'),
      coords = vector4(-1273.61, -885.89, 10.93, 310.93),
      actions = { 'burger', 'fries', 'drink', 'clearTray' },
    }
  },

  -- Kitchen Actions
  -- type: 'food' = orderable item with prop, 'utility' = action only (clear tray, etc)
  -- target.action: 'add' (default) adds item to tray, 'clear' clears tray
  -- target.icon/label/distance: ox_target options - all optional with defaults
  -- label: display name (used in notifications, orders) - required for 'food' type
  -- price/prop: required for 'food' type
  -- offset: {x, y, z, rx, ry, rz} adjustments when placed on tray (optional)
  Actions          = {
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
    clearTray = {
      type = 'utility',
      target = { icon = 'fa-solid fa-trash', label = 'Clear Tray', action = 'clear' },
    },
  },

  -- Tray Configuration
  Tray             = {
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
  TargetDefaults   = {
    action = 'add',
    icon = 'fa-solid fa-plus',
    label = 'Pick up %s', -- %s = item label
    distance = 2.0,
  },

  -- Timings (in milliseconds)
  SpawnInterval    = 10000, -- Time between customer spawns
  WalkTimeout      = 60000, -- Timeout if customer gets stuck
  PatienceOrder    = 10000, -- How long customer waits for order to be taken (DEBUG: 10s)
  PatienceFood     = 300000, -- How long customer waits for food delivery (5 minutes)
  EatTime          = 10000, -- How long customer takes to eat
  WaveIntervalMin  = 5000,  -- Min time between waves
  WaveIntervalMax  = 10000, -- Max time between waves
  SitDelay         = 2000,  -- Delay after sitting before waiting for order
  WalkoutTimeout   = 30000, -- Max time for customer to walk out before forced cleanup
  FadeoutDuration  = 1000,  -- Time for customer fadeout (in ms)

  -- Customer Models
  Models           = {
    'a_f_y_hipster_01',
    'a_m_y_business_02',
    'g_m_y_ballasout_01',
    'a_f_m_beach_01',
    'a_m_y_genstreet_01',
    'a_f_y_tourist_01'
  },

  -- Payment Settings
  PayPerItem       = 50,    -- Money earned per item delivered
  PaymentType      = 'cash', -- 'cash' or 'bank'

  -- Job Integration (set JobName to nil to disable job requirement)
  JobName          = nil,  -- Set to 'waiter' when you create the job in shared/jobs.lua
  RequireOnDuty    = false, -- Require player to be on duty to work

  -- Gameplay Limits
  MaxHandItems     = 6, -- Max items on tray at once
  OrderSizeMin     = 1, -- Min items per customer order
  OrderSizeMax     = 3, -- Max items per customer order
}
