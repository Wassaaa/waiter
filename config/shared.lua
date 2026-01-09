-- Shared configuration (used by both client and server)
return {
  -- Locations
  EntranceCoords      = vector4(-1266.05, -891.02, 10.48, 26.34),
  ProximityRadius     = 20.0, -- Distance to check for nearby players before spawning customers

  -- World Props to Delete (models that exist in the world at this location)
  PropsToDelete       = {
    joaat('prop_chair_01a'),
    joaat('prop_table_01'),
  },

  -- Furniture Layout (spawned by server, tracked by client)
  Furniture           = {
    -- 1
    { type = 'table', hash = joaat('prop_table_01'),  coords = vector4(-1267.09, -881.66, 10.94, 121.61) },
    { type = 'chair', hash = joaat('prop_chair_01a'), coords = vector4(-1268.32, -882.15, 10.94, 115.4) },
    { type = 'chair', hash = joaat('prop_chair_01a'), coords = vector4(-1267.62, -880.47, 10.94, 23.39) },
    -- 2
    { type = 'table', hash = joaat('prop_table_01'),  coords = vector4(-1265.67, -880.34, 10.94, 34.29) },
    { type = 'chair', hash = joaat('prop_chair_01a'), coords = vector4(-1266.21, -879.23, 10.94, 28.24) },
    { type = 'chair', hash = joaat('prop_chair_01a'), coords = vector4(-1264.71, -879.67, 10.94, 296.07) },
    -- 3
    { type = 'chair', hash = joaat('prop_chair_01a'), coords = vector4(-1276.19, -883.99, 10.94, 29.11) },
    { type = 'table', hash = joaat('prop_table_01'),  coords = vector4(-1275.65, -884.78, 10.94, 35.15) },
    { type = 'chair', hash = joaat('prop_chair_01a'), coords = vector4(-1274.89, -884.21, 10.93, 297.05) },
    -- 4
    { type = 'table', hash = joaat('prop_table_01'),  coords = vector4(-1277.42, -882.41, 10.94, 308.58) },
    { type = 'chair', hash = joaat('prop_chair_01a'), coords = vector4(-1276.66, -881.84, 10.94, 302.23) },
    { type = 'chair', hash = joaat('prop_chair_01a'), coords = vector4(-1276.78, -883.16, 10.94, 213.99) },
    -- 5
    { type = 'chair', hash = joaat('prop_chair_01a'), coords = vector4(-1277.84, -880.27, 10.94, 300.19) },
    { type = 'chair', hash = joaat('prop_chair_01a'), coords = vector4(-1279.11, -880.09, 10.93, 29.67) },
    { type = 'table', hash = joaat('prop_table_01'),  coords = vector4(-1278.56, -880.88, 10.94, 36.02) },
  },

  KitchenGrill        = { type = 'kitchen', hash = joaat('prop_bbq_5'), coords = vector4(-1273.61, -885.89, 10.93, 310.93) },

  -- Timings (in milliseconds)
  SpawnInterval       = 10000,  -- Time between customer spawns
  WalkTimeout         = 60000,  -- Timeout if customer gets stuck
  PatienceOrder       = 10000,  -- How long customer waits for order to be taken (DEBUG: 10s)
  PatienceFood        = 300000, -- How long customer waits for food delivery (5 minutes)
  EatTime             = 10000,  -- How long customer takes to eat
  WaveIntervalMin     = 5000,   -- Min time between waves
  WaveIntervalMax     = 10000,  -- Max time between waves
  SitDelay            = 2000,   -- Delay after sitting before waiting for order
  WalkoutTimeout      = 30000,  -- Max time for customer to walk out before forced cleanup
  FadeoutDuration     = 1000,   -- Time for customer fadeout (in ms)

  -- Customer Models
  Models              = {
    'a_f_y_hipster_01',
    'a_m_y_business_02',
    'g_m_y_ballasout_01',
    'a_f_m_beach_01',
    'a_m_y_genstreet_01',
    'a_f_y_tourist_01'
  },

  -- Menu Items
  Items         = {
    burger = { label = 'Burger', price = 25, prop = 'prop_cs_burger_01' },
    drink  = { label = 'Drink', price = 10, prop = 'prop_ecola_can' },
    fries  = { label = 'Fries', price = 15, prop = 'prop_food_chips' }
  },

  -- Payment Settings
  PayPerItem    = 50,     -- Money earned per item delivered
  PaymentType   = 'cash', -- 'cash' or 'bank'

  -- Job Integration (set JobName to nil to disable job requirement)
  JobName       = nil,   -- Set to 'waiter' when you create the job in shared/jobs.lua
  RequireOnDuty = false, -- Require player to be on duty to work

  -- Gameplay Limits
  MaxHandItems  = 3, -- Max items on tray at once
}
