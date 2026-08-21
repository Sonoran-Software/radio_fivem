# FiveM Resource

Sonoran Radio's FiveM Resource

## Custom radio frames

Custom frames are managed in the Radio web panel's customization menu. The
resource retrieves those community frames from the Radio backend and refreshes
them every five minutes.

Existing folders under `skins/` remain available as read-only legacy skins, so
upgrading does not remove a community's current custom work. `Config.frames`
continues to control per-player frame access for both local and backend-managed
frames. Use the local folder name for an installed skin and `community:<id>` for
a backend frame, such as `community:1`. With `permissionMode = 'none'`, all
available local and backend frames are selectable.

There is no automatic upload migration because a legacy skin may contain local
images and several portable, vehicle, HUD, or scanner layouts, while a managed
frame is one portable layout. To move a legacy portable frame into the managed
system, upload its body image in the customization menu and use the menu's
`skin.json` import option. Keep the legacy folder until the managed frame has
been verified in game; it can then be removed manually if it is no longer
needed.

## Mobile vehicle repeaters

Administrators with the existing `command.radioMenu` ACE can manage mobile repeater vehicles without knowing their spawn codes:

1. Enter the vehicle, or attach the trailer, that should receive a repeater.
2. Open `/radiomenu` and select **Radio Repeaters > Mobile Repeater Vehicles**.
3. Add or update the detected vehicle, set its label and range, and save it.

All players can use `/radio repeater` to open an activation-only menu for a compatible current vehicle or attached trailer. Administrators can also use the activation control in **Mobile Repeater Vehicles**. The former global G keybind is no longer registered, so unrelated vehicle controls do not produce repeater compatibility warnings.

The resource stores these entries in `mobileRepeaters.json`. On the first start after upgrading, any legacy `Config.repeaterVehicleSpawncodes` entries are imported once. After confirming the migration, remove that deprecated block from `config.lua`; future changes should be made through `/radiomenu`.
