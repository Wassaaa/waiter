# Job Integration Guide

This guide explains how to integrate the waiter resource with Qbox's job system.

## Step 1: Add Job to Qbox Core

Add the following to your `qbx_core/shared/jobs.lua` file:

```lua
['waiter'] = {
    label = 'Waiter',
    type = 'waiter',
    defaultDuty = true,
    offDutyPay = false,
    grades = {
        [0] = { name = 'Trainee', payment = 50, isboss = false },
        [1] = { name = 'Server', payment = 75, isboss = false },
        [2] = { name = 'Head Waiter', payment = 100, isboss = false },
        [3] = { name = 'Manager', payment = 150, isboss = true, bankAuth = true },
    },
}
```

## Step 2: Enable Job Requirement

In `waiter/config/client.lua`, change:

```lua
JobName = nil,           -- CHANGE THIS TO:
JobName = 'waiter',      -- Enable job requirement
RequireOnDuty = true,    -- Require players to clock in
```

## Step 3: Give Players the Job

### In-Game Command (Admin Only)

```
/setjob [playerid] waiter [grade]
```

### Or via Database

```sql
-- Give yourself the waiter job (replace YOUR_CITIZENID)
UPDATE players SET job = 'waiter', job_grade = 0 WHERE citizenid = 'YOUR_CITIZENID';
```

## Step 4: Add Duty Toggle (Optional)

### Option A: Use qbx_radialmenu

The radial menu should automatically show duty toggle for waiter job.

### Option B: Add a Manual Duty Zone

Add this to your waiter resource:

```lua
-- In client/main.lua, add:
RegisterCommand('toggleduty', function()
    local player = exports.qbx_core:GetPlayer()
    if player and player.PlayerData.job.name == 'waiter' then
        TriggerServerEvent('QBCore:ToggleDuty')
    end
end)
```

### Option C: Use qbx_management

If you have qbx_management installed, create a stash/duty location:

1. Go to your restaurant location
2. Use `/managementcreate waiter` to create a management zone
3. This will add duty toggle, stash, and boss menu

## Payment Configuration

### Payment Type

In `config/client.lua`:

```lua
PaymentType = 'cash',   -- Cash in hand
-- OR
PaymentType = 'bank',   -- Direct deposit
```

### Payment Amount

```lua
PayPerItem = 50,  -- $50 per item delivered
```

### How Payment Works

1. Player delivers order to customer
2. Client triggers `waiter:pay` event to server
3. Server validates:
   - Player has waiter job (if JobName is set)
   - Player is on duty (if RequireOnDuty is true)
4. Server adds money using `player.Functions.AddMoney()`
5. Payment is logged to qbx_core's money logs

## No Job Mode (Freelance)

To allow anyone to work without job requirement:

```lua
JobName = nil,          -- No job requirement
RequireOnDuty = false,  -- No duty requirement
```

## Testing

1. **Give yourself the job:**

   ```
   /setjob [your-id] waiter 0
   ```

2. **Clock in (if RequireOnDuty = true):**

   - Use radial menu
   - Or use management zone
   - Or use `/toggleduty` command

3. **Start working:**

   ```
   /setuprest
   ```

4. **Deliver orders and check payment**
   - You should see: "Earned $50 for 1 items!" (or similar)
   - Check your cash/bank with `/cash` or `/bank`

## Troubleshooting

### "You must have the waiter job to earn money"

- Check: Do you have the job? Use `/job` to verify
- Check: Is JobName set correctly in config?

### "You must be on duty to earn money"

- Check: Are you clocked in?
- Check: Is RequireOnDuty = true in config?

### No payment received

- Check server console for errors
- Check: Is qbx_core installed and running?
- Check F8 console for client errors

## Advanced: Society Account Integration

For advanced setups where restaurant earnings go to a shared account:

```lua
-- In server/main.lua, modify payment event:
RegisterNetEvent('waiter:pay', function(itemsDelivered)
    local src = source
    local amount = itemsDelivered * Config.PayPerItem

    -- Split payment: 70% to player, 30% to society
    local playerCut = math.floor(amount * 0.7)
    local societyCut = amount - playerCut

    player.Functions.AddMoney(Config.PaymentType, playerCut, 'waiter-job-payment')

    -- Add to society account (requires Renewed-Banking or qbx_management)
    exports['Renewed-Banking']:addAccountMoney('waiter', societyCut)
end)
```
