# Void Prison 🚔🔓

A sleek, premium, and feature-rich jail/prison resource for FiveM built for **QBox** and **QBCore** frameworks. Includes an interactive police tablet NUI monitoring system, multiple prisoner tasks to work off sentences, a custom database backend, personal bunk stashes, and advanced breakout mechanics.

---

## Key Features

- 🖥️ **Police Monitoring Tablet (NUI)**: A glassmorphic, modern tablet UI for police officers to track inmates, adjust sentence times, or release prisoners early.
- 🧳 **Inventory Confiscation & Locker**: Automatically confiscates inmate inventories upon jailing and stores them in a personal locker, retrievable upon release.
- 🛏️ **Inmate Cell Bunk Stashes**: Dedicated stashes near cell bunks where jailed players can store contraband and items out of sight of other inmates.
- 👕 **Appearance Saving & Custom Uniforms**: Captures players' original clothing layout (using `illenium-appearance`), places them in orange prison uniforms, and restores their exact original look on release.
- ⚙️ **Interactive Jobs & Prison Labor**: 
  - **Sweeping**: Attachment of broom, sweep animation, progress bar.
  - **Cafeteria Dishes**: Clean up and wash plates.
  - **Laundry**: Load clothes into washers.
  - **Electrical Panels**: High-risk minigame where failure causes electrical shocks and player pain.
  - Completing jobs reduces sentence times and has a chance of dropping contraband/breakout tools.
- 🚨 ** tampered Mainframe Breakouts**: Inmates or external allies can hack the prison terminal using a `gate_hack_device`. Successful hacks trigger loud sirens, alert police, and temporarily disable boundary containment.
- 🚧 **Escape Boundary Containment**: Jailed players attempting to escape the yard boundaries without a prison break active are teleported back to the yard and receive a sentence penalty (+30 months).

---

## Installation Guide

### 1. Import the Database Table
Run the provided SQL file in your database manager (like HeidiSQL, phpMyAdmin, or Navicat) to create the inmates table:
```sql
CREATE TABLE IF NOT EXISTS `jail_inmates` (
    `citizenid` VARCHAR(50) NOT NULL,
    `name` VARCHAR(100) NOT NULL,
    `jail_time` INT NOT NULL DEFAULT 0,
    `remaining_time` INT NOT NULL DEFAULT 0,
    `reason` TEXT DEFAULT NULL,
    `saved_appearance` LONGTEXT DEFAULT NULL,
    `jailed_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

### 2. Configure Your Resource
Open [config.lua](config.lua) and select your framework, inventory, and clothing preferences:
```lua
Config.Framework = 'qbx'       -- 'qbx' (QBox) or 'qb' (QBCore)
Config.Inventory = 'ox'        -- 'ox' (ox_inventory) or 'qb' (qb-inventory)
Config.Appearance = 'illenium' -- 'illenium' (illenium-appearance) or 'qb' (qb-clothing)
```

### 3. Add Shared Items (Only for qb-inventory/core)
If you are using QBCore framework/qb-inventory, add the items to your core's shared items database (e.g. `qb-core/shared/items.lua` or `qbx_core` configs):
```lua
['police_tablet'] = {['name'] = 'police_tablet', ['label'] = 'Police Inmate Monitor', ['weight'] = 500, ['type'] = 'item', ['image'] = 'police_tablet.png', ['unique'] = true, ['useable'] = true, ['shouldClose'] = true, ['combinable'] = nil, ['description'] = 'Secure LSPD Tablet used to monitor inmates.'},
['gate_hack_device'] = {['name'] = 'gate_hack_device', ['label'] = 'Prison Grid Tamper Tool', ['weight'] = 800, ['type'] = 'item', ['image'] = 'gate_hack_device.png', ['unique'] = false, ['useable'] = false, ['shouldClose'] = false, ['combinable'] = nil, ['description'] = 'A specialized device with wires and clips designed to hijack prison terminal mainframes.'},
```
*Note: If using `ox_inventory`, register these items in your `ox_inventory/data/items.lua` instead.*

### 4. Setup ps-mdt Sentencing Integration
- `void-prison` includes built-in net triggers for `police:server:JailPlayer` and `police:server:UnjailPlayer` events.
- If your version of `ps-mdt` uses exports, edit `ps-mdt/server/backend/sentencing.lua` and replace the default jail export trigger with:
```lua
exports['Void_Prisons']:JailPlayer(targetSource, sentenceTime, reason)
```

---

## Commands & Controls

- **Admin/Officer Commands**:
  - `/jail [ID] [Time] [Reason]`: Jails a target player.
  - `/unjail [ID]`: Unjails an active inmate immediately.
  - `/jailtablet`: Opens the police inmate monitoring application.
- **Inmate Controls**:
  - `[E]` on green cell bunk beds: Opens personal bunk stash.
  - `[E]` on laundry, cafeteria, electrical, or yard cleaning spots: Start labor.
- **Locker Controls**:
  - `[E]` at the front lobby counter (when released): Retrieve seized items.

---

## Dependencies
- `ox_lib`
- `oxmysql`
- Either `qb-core` or `qbx_core`
- Either `ox_inventory` or `qb-inventory`
- Either `illenium-appearance` or `qb-clothing`
