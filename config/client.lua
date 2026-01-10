-- Client-only configuration
return {
  -- Client-only locations
  -- Animations
  Anims = {
    Wave  = {
      { dict = "friends@frj@ig_1", anim = "wave_a" },
    },
    Anger = {
      { dict = "melee@unarmed@streamed_core", anim = "plyr_takedown_rear_lefthook" },
    },
    Eat   = {
      { dict = "mp_player_inteat@burger", anim = "mp_player_int_eat_burger_fp" },
    },
    Tray  = { dict = "amb@world_human_leaning@female@wall@back@hand_up@idle_a", anim = "idle_a" } -- Tray is special, keep 1 for now? Or listify? Let's leave Tray as single because it's a specific pose.
  },
}
