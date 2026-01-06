# Waiter Job

A client-side waiter job resource for FiveM/Qbox framework with full payment integration.

## Features

- 🪑 Dynamic furniture spawning (tables & chairs)
- 👥 NPC customer system with orders
- 🍔 Food tray system with visual props
- ⏱️ Customer patience mechanics
- 🎯 ox_target integration for interactions
- 💰 Server-side payment system with qbx_core integration
- 👔 Optional job system integration (can run as freelance or waiter job)
- 🔒 Configurable on-duty requirements

## Installation

1. Place `waiter` folder in your `resources` directory
2. Add `ensure waiter` to your `server.cfg`
3. Restart your server

## Dependencies

- **ox_lib** - Required for notifications and utilities
- **ox_target** - Required for interaction system
- **qbx_core** - Required for player/job/payment system

## Configuration

Edit `config/client.lua` to customize:

- Furniture locations
- Menu items & prices
- Customer spawn rates
- Patience timers
- Payment amounts & type
- Job requirements (enable/disable)

### Quick Start Modes

**Freelance Mode (Default):**

```lua
JobName = nil           -- Anyone can work
RequireOnDuty = false   -- No duty requirement
PaymentType = 'cash'    -- Cash payments
```

**Job Mode:**

```lua
JobName = 'waiter'      -- Requires waiter job
RequireOnDuty = true    -- Must clock in to work
PaymentType = 'bank'    -- Direct deposit
```

See [docs/JOB_INTEGRATION.md](docs/JOB_INTEGRATION.md) for full job setup guide.

## Commands

### Player Commands

- `/setuprest` - Start the restaurant (spawns furniture & kitchen)
- `/closerest` - Close the restaurant (cleanup all props/NPCs)
- `/newcustomer` - Manually spawn a customer

### Debug Commands

- `/tunetray <x> <y> <z> <rx> <ry> <rz>` - Adjust tray position

## Usage

1. Run `/setuprest` to spawn the restaurant
2. Wait for customers to arrive and sit
3. Use ox_target on customers to take orders
4. Go to the grill (kitchen) to pick up food items (burger, drink, fries)
5. Deliver food to customers by targeting them again
6. Get paid automatically when order is complete!

## Workflow

1. **Customer arrives** → Walks to seat and sits down
2. **Take Order** → Target customer, they'll give you their order
3. **Prepare Food** → Go to kitchen grill, pick up items (hold up to 3)
4. **Deliver Food** → Target customer again to deliver their order
5. **Get Paid** → Receive payment (cash or bank) automatically
6. **Customer eats** → After eating, they leave

## Payment System

The resource features a full server-side payment system:

- **Validation**: Server checks job and duty status before payment
- **Security**: All payments processed server-side (no client manipulation)
- **Logging**: All transactions logged via qbx_core's money logs
- **Configurable**: Set payment amount, type (cash/bank), and job requirements

### Payment Flow

```
Client: Deliver Food → Server: Validate Player → Server: Add Money → Client: Notification
```

## Structure

```
waiter/
├── fxmanifest.lua
├── README.md
├── config/
│   └── client.lua       # All configuration
├── client/
│   ├── state.lua        # State management & utilities
│   ├── main.lua         # Entry point & commands
│   ├── tray.lua         # Tray/hand system
│   ├── customers.lua    # Customer logic & payments
│   └── furniture.lua    # Furniture spawning
├── server/
│   └── main.lua         # Payment processing & validation
└── docs/
    └── JOB_INTEGRATION.md  # Full job setup guide
```

## Future Plans

- [ ] Server-side entity spawning (multiplayer support)
- [x] Payment system integration
- [ ] Localization support
- [x] Job framework integration (qbx_core)
- [ ] Advanced order system (recipes, cooking minigame)
- [ ] Customer ratings & tips based on service speed
- [ ] Society account integration for shared earnings
- [ ] Boss menu for managing employees & viewing stats
- [ ] Multiple restaurant locations

## Troubleshooting

### Payments not working

1. Check qbx_core is installed and running
2. Check server console for payment errors
3. Verify player has correct job (if JobName is set)
4. Verify player is on duty (if RequireOnDuty is true)

### Customers getting stuck

- This is a known rare issue with GTA pathfinding
- Use `/newcustomer` to spawn a fresh customer
- Furniture collision ghosting should prevent most issues

### Props disappearing

- World props auto-delete every 5 seconds
- Your spawned props are protected
- Check for conflicts with other map resources

## License

MIT

## Credits

Author: Wassaaa
Framework: Qbox (qbx_core)
