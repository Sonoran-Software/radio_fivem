# FiveM Resource

Sonoran Radio's FiveM Resource

## Custom radio frames

Custom frames are managed in the Radio web panel's Customize > Overlay menu.
The resource retrieves those community frames from the Radio backend on startup
and refreshes them every five minutes. Saving an overlay in the panel also sends
an authenticated `frames_updated` notification to configured game-server push
URLs. The resource immediately refetches frames and updates connected players.
Player permission checks use the cache without making API requests. Failed
refreshes retain the last successful cache, and polling recovers missed notifications.

On startup, the resource safely migrates folders under `skins/`:

1. Every skin config is validated and each local frame image is uploaded.
2. The on-foot, vehicle, and aircraft layouts are merged into one managed frame.
   FiveM-only HUD and scanner layouts are retained with that frame as legacy
   extras so the migration does not remove existing behavior.
3. A fresh backend read verifies an alias for every original skin folder.
4. Only after verification, `skins/` is renamed to `skins_old` (or the next
   available numbered suffix). Any validation, upload, API, or verification
   failure leaves `skins/` untouched so the migration can be retried safely.

The backend merge is idempotent and keys each migrated frame by its original
folder name, so restarting does not create duplicates. Content-hashed image
uploads are also safe to repeat.

`Config.frames` remains the source of FiveM per-player frame permissions. An
existing folder entry such as `default` automatically resolves to its migrated
backend frame, so communities do not need to rewrite permission groups during
the upgrade. New managed frames can be referenced explicitly as `frame:<id>`.
With `permissionMode = 'none'`, every available managed frame is selectable.

## Mobile vehicle repeaters

Administrators with the existing `command.radioMenu` ACE can manage mobile repeater vehicles without knowing their spawn codes:

1. Enter the vehicle, or attach the trailer, that should receive a repeater.
2. Open `/radiomenu` and select **Radio Repeaters > Mobile Repeater Vehicles**.
3. Add or update the detected vehicle, set its label and range, and save it.

All players can use `/radio repeater` to open an activation-only menu for a compatible current vehicle or attached trailer. Administrators can also use the activation control in **Mobile Repeater Vehicles**. The former global G keybind is no longer registered, so unrelated vehicle controls do not produce repeater compatibility warnings.

The resource stores these entries in `mobileRepeaters.json`. On the first start after upgrading, any legacy `Config.repeaterVehicleSpawncodes` entries are imported once. After confirming the migration, remove that deprecated block from `config.lua`; future changes should be made through `/radiomenu`.
