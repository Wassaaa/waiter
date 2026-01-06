-- Shared configuration (used by both client and server)
return {
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
