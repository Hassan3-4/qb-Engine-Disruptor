# 🚔 Vehicle-stop (Engine Disruptor)

Police-only engine disruptor for QBCore servers that safely decelerates a target vehicle, stalls the engine, and prevents re-start for a configurable duration (default 30s). No ox_lib required. Built for OneSync.

![Engine Disruptor](./assets/engine_disruptor.png)

## ✨ What it does

- Officer uses an item to “arm” the disruptor, then presses J to lock the nearest non-police vehicle within range.
- Target vehicle decelerates smoothly, the engine stalls, and engine start is blocked for 30 seconds.
- A HUD countdown shows remaining lock time to the driver. After the lock ends, the driver must press G to manually start.
- Cooldowns prevent spam (officer cooldown + per-target cooldown). Server and clients use a synchronized timebase for accurate timers.

## 🧩 Key features

- Police-only, server-authoritative checks (job, distance, safe-zones, vehicle class/model, siren requirement optional, NPC exclusion, target speed).
- Nearest-vehicle selection in a cone around the officer; avoids your own vehicle and police vehicles.
- Hold-to-arm with progressbar; lock on J keybind (rebindable in FiveM settings).
- Per-vehicle independent timers so locking a second vehicle won’t shorten the first.
- Robust engine-off enforcement: if anything tries to turn it on during lock, it’s turned off again.
- qb-vehiclekeys integration keeps starting fully manual: W/S won’t auto-start; only G starts the engine, and G is refused during a lock.
- Admin toggle command to globally enable/disable.

## 📦 Dependencies

Required (start these before Vehicle-stop):

- qb-core (QBCore framework)
- qb-vehiclekeys (with the manual-start and disruptor-guard changes described below)
- progressbar (resource name exactly `progressbar`)
- qb-inventory and qb-notify (whatever you normally use with QBCore)

Recommended:

- OneSync enabled (for reliable statebags and timer sync)

No ox_lib dependency.

## 🗂️ Files in this resource

- fxmanifest.lua — resource manifest
- shared/config.lua — all tuning in one place (range, cooldowns, exclusions, UI toggles)
- server/main.lua — validations, activation, timers, exports, admin command
- client/
	- officer.lua — arming UX, nearest-vehicle selection, J keybind to lock
	- target.lua — deceleration, engine stall, HUD, enforcement during lock
	- hooks.lua — client export and re-stall safeguard
	- safezones.lua — simple zone checks (empty by default)
	- ui.lua — drawing helpers (text and brackets)
- assets/engine_disruptor.png — icon used in docs/UI

## ⚙️ Installation

1) Place this folder at `resources/[police]/Vehicle-stop`.

2) Ensure resource order in `server.cfg` (put these before Vehicle-stop):

```cfg
ensure qb-core
ensure qb-vehiclekeys
ensure progressbar
ensure qb-inventory
ensure qb-smallresources
ensure [police]
ensure Vehicle-stop
```

3) Register the item in `qb-core` (in `qb-core/shared/items.lua`):

```lua
['engine_disruptor'] = {
	name = 'engine_disruptor', label = 'Engine Disruptor', weight = 500,
	type = 'item', image = 'engine_disruptor.png', unique = true,
	useable = true, shouldClose = true, description = 'Police engine disruptor device.'
},
```

4) Add the item image for your inventory UI:

- Copy `resources/[police]/Vehicle-stop/assets/engine_disruptor.png`
- Paste into `qb-inventory/html/images/engine_disruptor.png`

5) qb-vehiclekeys integration (manual engine start + disruptor guard):

- Engine must be started manually with G; holding W/S will NOT auto-start.
- When you take the driver seat, engine remains off until G is pressed (a hint appears once).
- While the disruptor lock is active, pressing G will be refused and a message shows the remaining seconds.

This repo already includes the minimal integration inside `qb-vehiclekeys/client/main.lua`:

- Keybind: `RegisterKeyMapping('engine', ..., 'G')` (vanilla qb-vehiclekeys already uses G).
- G engine command and `ToggleEngine(veh)` now call Vehicle-stop’s client export to check lock state:
	- `local locked, left = exports['Vehicle-stop']:IsVehicleLockedClient(veh)`
	- If locked, notify and refuse to start.
- A small loop enforces “fully manual start” by disabling controls 71/72 (W/S) when engine is off or when entering the driver seat.

If you use a different vehicle keys resource, port the following logic:

- Do not auto-start engine on accelerate (W/S). Require a dedicated key (G) to start.
- Refuse G when `IsVehicleLockedClient(veh)` (or server export) returns locked=true.
- When the player first sits in the driver seat, keep engine off until G.

## 🎮 Controls (default)

- Use item: inventory use of Engine Disruptor
- Arm/Disarm: using the item toggles “aiming” mode
- Lock target: J (FiveM keybind “Vehicle Disruptor: Lock nearest vehicle”)
- Start engine (all players): G (FiveM keybind in qb-vehiclekeys)

Both keybinds can be re-mapped under FiveM Settings > Key Bindings.

## 🔧 Configuration (shared/config.lua)

- General: `enabled`, `rangeMeters`, `armHoldMs`, `lockSeconds`, `officerCooldownSeconds`, `perTargetCooldownSeconds`
- Jobs: `allowedJobs` (default: police), `requirePoliceVehicle`, `nearPoliceVehicleMeters`, `requireSirenOn`, `minTargetSpeedKmh`
- Exclusions: `excludeJobs` (police/ems/fire), `excludeClasses` (bikes/boats/helis/planes), `excludeNPC`
- Models: `modelBlacklist` and `policeVehicleModels` prevent locking police vehicles
- Deceleration: `decelProfiles` for speed ramps based on current speed
- Stacking: `allowRefresh`, `refreshWindowSeconds`, `refreshMaxCount`
- Safe-zones: `enableSafeZones`, `safeZones = { { coords=vector3(x,y,z), radius=50.0 }, ... }`
- UI/SFX: `showOfficerHints`, `showCivilianNotify`, `showHudTimer`, `playSfx`
- Item: `itemName = 'engine_disruptor'` (infinite-use; no charges metadata needed)

## 🔌 Exports and commands

- Server export: `exports['Vehicle-stop']:IsVehicleLockedByDisruptor(entity)` → `locked:boolean, remainingSeconds:number`
- Client export: `exports['Vehicle-stop']:IsVehicleLockedClient(entity)` → `locked:boolean, remainingSeconds:number`
- Admin command: `/disruptor_toggle` (QBCore permission: `admin`) — enables/disables the disruptor globally

## 🧠 How it works (brief)

- Officer arms the device (hold-to-arm with progressbar) and presses J to attempt a lock on the nearest valid vehicle in range.
- Server validates job, distance, exclusions, safe-zones, siren requirement (optional), NPC exclusion, and cooldowns.
- On success, the server marks the vehicle’s statebag (`DisruptorActive`, `DisruptorNoStart`, `DisruptorEndsAt`). Clients apply deceleration and stall.
- A server-side thread independently expires each vehicle based on its own timer and starts per-target cooldowns.
- Clients show a HUD timer and enforce engine-off while `DisruptorNoStart` is true.

## 🧪 Safe-zones

Safe-zones are simple spheres. Add entries to `Config.safeZones`:

```lua
Config.safeZones = {
	{ coords = vector3(441.1, -981.8, 30.7), radius = 60.0 }, -- Mission Row PD
}
```

Both the officer’s position and the target vehicle’s position are checked.

## ✅ Acceptance criteria summary

- Police-only usage with nearest vehicle selection, hold-to-arm, and J to lock.
- Target decelerates smoothly, engine stalls, and lock persists for the full duration; HUD timer visible to the driver.
- Lock cannot be bypassed by throttle or other scripts; engine is re-stalled if necessary.
- Manual engine start for everyone (G only); W/S won’t auto-start.
- Cooldowns: officer cooldown and per-target cooldown enforced server-side.
- Admin toggle works; timers independent per vehicle; time-synced across server and clients.

## 🛠️ Troubleshooting

- “Engine still starts with W”: Ensure your `qb-vehiclekeys/client/main.lua` includes the manual-start enforcement (disables controls 71/72 while engine is off / entering driver seat) and clears only on G.
- “Disruptor key not working”: The lock keybind is registered as `vehdisruptor_lock` and defaults to J; rebind in FiveM Settings.
- “Progressbar missing”: Resource name must be `progressbar` and ensured before Vehicle-stop.
- “Item missing”: Add the item in `qb-core/shared/items.lua` and place the icon in `qb-inventory/html/images/`.
- “Won’t lock police/NPC vehicles”: This is by design; adjust `modelBlacklist`, `policeVehicleModels`, or `excludeNPC` in `shared/config.lua`.
- “Timers weird or not ending”: Ensure OneSync is enabled; we use network time for sync. Also verify no scripts are deleting/recreating vehicles mid-lock.

## 📜 Changelog (highlights)

- 1.0.0
	- Infinite-use item (no charges consumed)
	- Keybind to lock via FiveM mapping (default J)
	- Pre-use cooldown feedback (shows remaining cooldown instead of arming)
	- Accurate, network-synced HUD timer and per-vehicle independent expiry
	- qb-vehiclekeys integration for manual engine start (G only) and lock guard

---

Made with care for high-speed but safe vehicle stops 🛑. Questions or ideas? Open an issue or ping your devs.
