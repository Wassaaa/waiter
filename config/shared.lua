-- Shared configuration (used by both client and server)
return {
  RestaurantCenter = vector3(-1273.85, -882.37, 10.93),

  Entrances        = {
    vector4(-1266.05, -891.02, 10.48, 26.34),
    vector4(-1258.21, -886.26, 10.83, 49.83),
    vector4(-1276.35, -895.21, 10.23, 339.18),
    vector4(-1286.10, -879.67, 10.42, 275.02),
  },

  Exits            = {
    vector4(-1258.44, -882.29, 10.91, 301.73),
    vector4(-1288.71, -873.18, 10.79, 23.02),
  },
  Management       = {
    coords = vector4(-1269.15, -878.01, 10.93, 37.34),
    radius = 1.0,
    target = {
      open = { icon = 'fa-solid fa-door-open', label = 'Open Restaurant' },
      close = { icon = 'fa-solid fa-door-closed', label = 'Close Restaurant' },
    }
  },
  ProximityRadius  = 30.0, -- Distance for customer spawning, furniture loading, and prop cleanup

  -- Logging Level ('error', 'warn', 'info', 'debug')
  -- This sets ox:printlevel:waiter automatically on start
  LogLevel         = 'debug',

  -- World Props to Delete (models that exist in the world at this location)
  PropsToDelete    = {
    joaat('prop_chair_01a'),
    joaat('prop_table_01'),
  },

  -- Furniture Layout (spawned by server, tracked by client)
  -- Types: 'table', 'chair', 'kitchen'
  -- Kitchen props can have 'items' array to specify which menu items can be picked up from them
  Furniture        = {

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
      coords = vector4(-1273.61, -885.89, 10.93, 128.93),
      actions = { 'burger', 'fries', 'drink', 'coffee' },
      trayCoords = vector4(-1273.5167, -885.8346, 11.8799, 129.5214),
      standPos = vector4(-1272.7399, -885.2156, 10.9300, 129.5215),
      dispensers = {
        drink = vector4(-1273.8322, -885.2936, 11.8799, 0.0000),
        burger = vector4(-1273.9316, -885.6337, 11.9299, 0.0000),
        coffee = vector4(-1273.0303, -886.2280, 11.9299, 0.0000),
        fries = vector4(-1273.4048, -886.2617, 11.8799, 0.0000),
      },
    }
  },

  -- Kitchen Actions
  -- type: 'food' = orderable item with prop, 'utility' = action only (clear tray, etc)
  -- label: display name (used in notifications, orders) - required for 'food' type
  -- price/prop: required for 'food' type
  Actions          = {
    burger = {
      type = 'food',
      label = 'Burger',
      price = 25,
      prop = 'prop_cs_burger_01',
    },
    drink = {
      type = 'food',
      label = 'Drink',
      price = 10,
      prop = 'ng_proc_sodacup_01a',
    },
    fries = {
      type = 'food',
      label = 'Fries',
      price = 15,
      prop = 'prop_food_bs_chips',
      physicsProxy = 'prop_paper_bag_small',
    },
    coffee = {
      type = 'food',
      label = 'Coffee',
      price = 15,
      prop = 'p_amb_coffeecup_01',
    },
  },

  -- Tray Configuration
  Tray             = {
    prop = 'prop_food_tray_01',
    -- Attachment to player hand (bone 57005 = right hand)
    bone = 57005,
    offset = { x = 0.1, y = 0.05, z = -0.1 },
    rotation = { x = 190.0, y = 300.0, z = 50.0 },
  },

  -- Timings (in milliseconds)
  SpawnInterval    = 4000,   -- Time between customer spawns
  WalkTimeout      = 60000,  -- Timeout if customer gets stuck
  PatienceOrder    = 10000,  -- How long customer waits for order to be taken (DEBUG: 10s)
  PatienceFood     = 300000, -- How long customer waits for food delivery (5 minutes)
  EatTime          = 10000,  -- How long customer takes to eat
  WaveIntervalMin  = 5000,   -- Min time between waves
  WaveIntervalMax  = 10000,  -- Max time between waves
  SitDelay         = 2000,   -- Delay after sitting before waiting for order
  WalkoutTimeout   = 30000,  -- Max time for customer to walk out before forced cleanup
  FadeoutDuration  = 1000,   -- Time for customer fadeout (in ms)

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
  PayPerItem       = 50,     -- Money earned per item delivered
  PaymentType      = 'cash', -- 'cash' or 'bank'

  -- Job Integration (set JobName to nil to disable job requirement)
  JobName          = 'waiter', -- Set to 'waiter' when you create the job in shared/jobs.lua
  RequireOnDuty    = false,    -- Require player to be on duty to work

  -- Gameplay Limits
  MaxHandItems     = 32, -- Max items on tray at once
  OrderSizeMin     = 1,  -- Min items per customer order
  OrderSizeMax     = 3,  -- Max items per customer order
}
