# FiveM Resource

Sonoran Radio's FiveM Resource

## Mobile vehicle repeaters

Administrators with the existing `command.radioMenu` ACE can manage mobile repeater vehicles without knowing their spawn codes:

1. Enter the vehicle, or attach the trailer, that should receive a repeater.
2. Open `/radiomenu` and select **Radio Repeaters > Mobile Repeater Vehicles**.
3. Add or update the detected vehicle, set its label and range, and save it.

All players can use `/radio repeater` to open an activation-only menu for a compatible current vehicle or attached trailer. Administrators can also use the activation control in **Mobile Repeater Vehicles**. The former global G keybind is no longer registered, so unrelated vehicle controls do not produce repeater compatibility warnings.

The resource stores these entries in `mobileRepeaters.json`. On the first start after upgrading, any legacy `Config.repeaterVehicleSpawncodes` entries are imported once. After confirming the migration, remove that deprecated block from `config.lua`; future changes should be made through `/radiomenu`.
