# Sonoran Radio Error and Warning Codes

This file is the source-of-truth registry for structured log codes emitted by this resource.

## Errors

| Code | Internal Key | Meaning | First Troubleshooting Step |
| --- | --- | --- | --- |
| ERR-101 | ERR_OX_LIB_NOT_STARTED | `ox_lib` was selected or required, but the resource was not started before Sonoran Radio. | Start `ox_lib` before this resource and restart Sonoran Radio. |
| ERR-102 | ERR_OX_LIB_INIT_LOAD_FAILED | `@ox_lib/init.lua` could not be loaded. | Verify that `ox_lib` is installed correctly and that `init.lua` exists. |
| ERR-103 | ERR_OX_LIB_NOTIFY_UNAVAILABLE | `ox_lib` notifications were selected, but `lib.notify` is unavailable. | Confirm `ox_lib` is running and that its initialization completed without errors. |
| ERR-104 | ERR_RADIO_ITEM_INVENTORY_MISSING | No supported inventory resource was detected while `enforceRadioItem` is enabled. | Start a supported inventory resource such as `qb-inventory` or `ox_inventory`, or disable `enforceRadioItem`. |
| ERR-105 | ERR_RADIO_ITEM_FRAMEWORK_MISSING | No supported framework resource was detected while `enforceRadioItem` is enabled. | Start a supported framework such as `qb-core` or `qbx_core`, or disable `enforceRadioItem`. |
| ERR-106 | ERR_API_CREDENTIALS_MISSING | The API key or community ID is missing from configuration. | Set `apiKey` and `comId` in the resource configuration and reload the resource. |
| ERR-107 | ERR_API_FATAL_DISABLED | A fatal API error disabled the resource until configuration is corrected and the resource is restarted. | Fix the reported API credential or community issue, then restart the resource. |
| ERR-108 | ERR_API_CRITICAL_ABORTED | A request was aborted because the resource is already in a critical API error state. | Resolve the earlier fatal API issue before retrying requests. |
| ERR-109 | ERR_FRAMES_DEPARTMENTS_MISSING | `Config.frames.departments` is missing for the selected permission mode. | Add the required departments list under `Config.frames.departments`. |
| ERR-110 | ERR_JAMMERS_PERMISSION_MODE_INVALID | The configured permission mode for radio jammers is invalid. | Check the jammer permission mode value in config and change it to a supported option. |
| ERR-111 | ERR_RADIO_ITEM_CONFIG_MISSING | Radio item enforcement is enabled, but `Config.RadioItem` is missing. | Define `Config.RadioItem` in configuration or disable radio item enforcement. |
| ERR-112 | ERR_SCANNER_ITEM_CONFIG_MISSING | Scanner item enforcement is enabled, but `Config.ScannerItem` is missing. | Define `Config.ScannerItem` in configuration or disable scanner item enforcement. |
| ERR-113 | ERR_QBOX_OX_RADIO_ITEM_MISSING | The configured radio item does not exist in Ox Inventory on Qbox. | Add the configured radio item to `/ox_inventory/data/items.lua` or fix the item name. |
| ERR-114 | ERR_QBOX_OX_SCANNER_ITEM_MISSING | The configured scanner item does not exist in Ox Inventory on Qbox. | Add the configured scanner item to `/ox_inventory/data/items.lua` or fix the item name. |
| ERR-115 | ERR_COMMUNITY_CHANNELS_FETCH_FAILED | Community channels could not be fetched from the radio service. | Check the status code in the server log and verify API connectivity. |
| ERR-116 | ERR_SKIN_SAVE_FAILED | A radio skin configuration file could not be saved. | Verify the target file path is writable by the server process. |
| ERR-117 | ERR_CONFIG_SAVE_FAILED | A JSON configuration file could not be saved. | Check file permissions and confirm the resource directory is writable. |
| ERR-118 | ERR_SERVER_IP_SET_FAILED | The resource could not register or update the server IP with the radio service. | Verify `apiKey`, `comId`, and outbound API connectivity. |
| ERR-119 | ERR_SERVER_IP_INVALID_ROOM | The radio service returned an invalid `roomId` while setting the server IP. | Check the API response and confirm the configured community is valid for radio. |
| ERR-120 | ERR_FRAMES_CONFIG_MISSING | `Config.frames` is missing. | Add the `Config.frames` block to the configuration. |
| ERR-121 | ERR_SERVER_SPEAKERS_SET_FAILED | The resource could not synchronize server speaker locations with the radio service. | Check the API response and confirm speaker configuration is valid. |
| ERR-122 | ERR_SERVER_NAME_SET_FAILED | The resource could not update a user display name in the radio service. | Verify API connectivity and confirm the target user exists in the linked community. |
| ERR-123 | ERR_INVALID_COMMUNITY_ID | The configured community ID is invalid or not enabled for the API. | Confirm the configured community ID matches a community with radio API access. |

## Warnings

| Code | Internal Key | Meaning | First Troubleshooting Step |
| --- | --- | --- | --- |
| WRN-201 | WRN_LB_PHONE_NOT_STARTED | lb-phone integration is waiting for the `lb-phone` resource to start. | Start `lb-phone` if phone integration is expected. |
| WRN-202 | WRN_LUXART_RESOURCE_DEFAULTED | `Config.luxartResourceName` was empty, so the default `lvc` resource name was applied. | Set `Config.luxartResourceName` explicitly if your Luxart resource uses a different name. |
| WRN-203 | WRN_API_REQUEST_FAILED | A Sonoran Radio API request failed. | Inspect the logged request type and reason, then verify API connectivity. |
| WRN-204 | WRN_API_ENDPOINT_UNREGISTERED | An API request was attempted for an endpoint type that is not registered. | Register the endpoint type before making that request. |
| WRN-205 | WRN_GEO_ZONE_SYNC_FAILED | Geo and degrade zones could not be synchronized with the radio service. | Check the earlier API response details for the zone sync request. |
| WRN-206 | WRN_COMMUNITY_CHANNELS_FETCH_FAILED | Community channels could not be fetched for a player request. | Check the HTTP status in the warning and verify the player has valid access to radio data. |
| WRN-207 | WRN_SKIN_SAVE_DEBUG_BLOCKED | A client attempted to save a radio skin while debug mode was disabled. | Verify the caller is expected and only enable the save path during debugging. |
| WRN-208 | WRN_CONFIG_RENAME_FAILED | A default configuration file could not be renamed to its writable target path. | Check whether the destination file already exists or is locked by the OS. |
| WRN-209 | WRN_CONFIG_SAVE_FALLBACK | Saving a configuration file failed, so the resource fell back to writing the default file. | Check permissions on the preferred config file path. |
| WRN-210 | WRN_SERVER_IP_USING_EXISTING_ROOM | The server IP update failed, but an existing `roomId` was reused while retrying in the background. | Confirm the existing `roomId` is still valid and investigate the underlying API failure. |
| WRN-211 | WRN_SERVER_IP_RETRYING | The server IP update failed and will be retried. | Check API availability and confirm the configured credentials are correct. |
| WRN-212 | WRN_SERVER_ID_CONFIG_WRITE_FAILED | The resolved `serverId` could not be written back to `config.lua`. | Check whether `config.lua` is read-only or locked. |
| WRN-213 | WRN_APIKEY_CONVAR_UNINITIALIZED | The `apiKey` convar was not initialized from `sonoranradio.cfg`. | Ensure `sonoranradio.cfg` is executed before the resource starts. |
| WRN-214 | WRN_CHATTER_EXCLUSIONS_OVERWRITE_DEPRECATED | `Config.chatterExclusions` overwrote `earpieces.json` even though the config path is deprecated. | Remove `Config.chatterExclusions` from config and migrate to `earpieces.json`. |
| WRN-215 | WRN_CHATTER_EXCLUSIONS_DEPRECATED | `Config.chatterExclusions` is deprecated. | Move chatter exclusion management to `earpieces.json` or the in-game menu. |
| WRN-216 | WRN_MOBILE_REPEATERS_CONFIG_MIGRATED | Legacy `Config.repeaterVehicleSpawncodes` entries were imported into `mobileRepeaters.json`. | Remove the deprecated `Config.repeaterVehicleSpawncodes` block and use `/radiomenu` for future changes. |
| WRN-217 | WRN_LISTENER_PRO_REQUIRED | Nearby radio chatter and scanners were disabled because the community does not have a Pro subscription. | Upgrade the Radio community to Pro, or set `Config.chatter` to `false`. |
