-- Client-only configuration
return {
  -- Client-only locations
  ExitCoords          = vector4(-1258.44, -882.29, 10.91, 301.73),
  KitchenCoords       = vector4(-1273.61, -885.89, 10.93, 310.93),

  -- Animations (client-only)
  Anims               = {
    Wave  = { dict = "friends@frj@ig_1", anim = "wave_a" },
    Anger = { dict = "melee@unarmed@streamed_core", anim = "light_punch_a" },
    Eat   = { dict = "mp_player_inteat@burger", anim = "mp_player_int_eat_burger_fp" },
    Tray  = { dict = "amb@world_human_leaning@female@wall@back@hand_up@idle_a", anim = "idle_a" }
  },

  -- Debug
  AutoStartRestaurant = true, -- Auto-start restaurant on resource load
}
