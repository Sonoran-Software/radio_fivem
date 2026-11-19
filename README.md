# FiveM Resource

Sonoran Radio's FiveM Resource

## Configure FiveM in Radio Admin

For a new server, download its package from **Admin > Game Integration > FiveM Installation**.
The generated `config.lua` contains your community ID, API key, and selected Radio server ID.
Change gameplay settings in **FiveM Settings** and apply them by rerunning your installation command
or restarting the `sonoranradio` resource. Startup reads the saved settings from Radio before initializing features.

Existing installations continue to start with their local `config.lua` and placement files
while migration is pending. To switch to Radio Admin, run `sonoranradio migrate` in the FiveM
server console. The command imports and verifies settings and placements, preserving collections
already saved in Radio Admin. It then rewrites `config.lua` with the community ID, API key, and room ID,
and moves the original config and obsolete JSON files to `lua/config/.legacy-configuration-*`.
Refresh the status in Radio Admin to edit the migrated settings. Placement changes go to Radio
as soon as migration finishes. The resource loads its managed gameplay settings on its next
start. If local cleanup reports `WRN-220`, check write permissions and rerun
`sonoranradio migrate`.

Keep the bootstrap credentials private on the server. Advanced host overrides and custom Lua
callbacks are optional. Migration retains supported host overrides in the server-only backup.
Custom Lua callbacks are archived with the original config and stop running after restart.
Startup saves verified settings and placements together in the server-only
`lua/config/.configuration-cache.json`. If Radio is temporarily unavailable, the resource can
use this backup for the same API origin, community, and room. A managed installation with no
verified settings waits for a working connection and restart.
If saved settings are cleared in Radio, the next successful startup check on an installation
with legacy settings in `config.lua` returns it to legacy mode and shows the migration warning.

## FiveM placements

Use `/radiomenu` to place and move towers, server racks, fixed repeaters, speakers, scanners,
and static jammers, and to configure earpieces and mobile repeater vehicles. The managed
resource saves those changes to Radio and updates its local backup after confirmation.
**Admin > Game Integration > FiveM Placements** shows the saved entries for each server and
lets admins delete them. Restart the resource to load a portal deletion.

The resource seeds unconfigured collections on startup from legacy placement files or the
bundled presets. Presets include towers, racks, a fixed repeater, speakers, scanners, and
earpieces. Static jammers and mobile repeater vehicles start empty. Collections already
saved to Radio take precedence, including empty collections.

## Automatic guest login

Enable **Force guest login** in FiveM Settings to automatically sign radio users in as guests when they open the radio. Legacy installations use `Config.forceGuestLogin`. They do not need a Sonoran account or an in-game login choice. Guest tokens still use the configured community ID and API key. The setting defaults to `false`.

Guest permissions come from the player's ACE permissions in this mode, including `sonoranradio.channel.<channel id>` (or `sonoranradio.channel.<channel name>`) for nonpublic channels. This works even when `Config.acePermSync = false`; that setting still controls Sonoran account syncing in normal mode. `Config.acePermsForRadio` and `Config.acePermsForRadioGuests` continue to restrict access through `sonoranradio.use` and `sonoranradio.guest` when enabled. Grant those ACEs to every intended radio user if you enable the corresponding restrictions.

## Custom radio frames

Custom frames are managed under **Admin > Overlay** in the Radio web panel.
The resource retrieves those community frames from the Radio backend on startup
and refreshes them every five minutes. Saving an overlay in the panel also sends
an authenticated `frames_updated` notification to configured game-server push
URLs. The resource immediately refetches frames and updates connected players.
Player permission checks use the cache without making API requests. Failed
refreshes retain the last successful cache, and polling recovers missed notifications.

Fresh installs use the frames from the Radio backend. If an existing install
has a `skins/` folder, the resource safely migrates it on startup:

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

Managed installations save these entries in **FiveM Placements**. Startup can import legacy `mobileRepeaters.json` and `Config.repeaterVehicleSpawncodes` entries when the portal collection is unconfigured. After confirming the migration, remove the deprecated block from `config.lua` and use Radio Admin or `/radiomenu` for future changes.
