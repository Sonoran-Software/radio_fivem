-- Built-in defaults for network-independent resource startup and legacy migration.
local defaults = {}

defaults.defaultSkinId = nil -- Configure the default skin for the radio (e.g. 'default', 'hi-vis')
defaults.defaultEscapeMode = 'keep' -- keep | hide | transmit_only -- Default escape mode for the radio (player can change this in the settings)
defaults.chatter = true -- Pro only: hear nearby radio chatter and enable scanners
defaults.towerRepairTimer = 20 -- Time in seconds to repair towers
defaults.rackRepairTimer = 15  -- Time in seconds to repair server racks
defaults.antennaRepairTimer = 15 -- Time in seconds to repair cell repeater antennas
defaults.acePermSync = false -- Sync radio community auto-approval and permissions with ace permissions
defaults.forceGuestLogin = false -- Automatically log all authorized radio users in as guests, with guest permissions from ACE (no Sonoran login)
defaults.acePermsForServerRepair = false -- Restrict repairs for servers to an ace permission
defaults.acePermsForTowerRepair = false -- Restrict repairs for towers to an ace permission
defaults.acePermsForAntennaRepair = false -- Restrict repairs for cell repeater antennas to an ace permission
defaults.acePermsForScanners = false -- Restrict using the scanner to an ace permission
defaults.acePermsForRadio = false -- Restrict usage of the radio to an ace permission
defaults.acePermsForRadioGuests = false -- Restrict users joining the radio as a guest to an ace permission
defaults.acePermsForRadioUsers = false -- Restrict usage of /radiousers to an ace permission
defaults.syncPlayerNameToRadio = false -- Sync the player's in-game character name to their Sonoran Radio display name
defaults.enforceRadioItem = false
defaults.RadioItem = {		 -- Changes to framework item registrations can require a full server restart.
	name = 'sonoran_radio',  -- Item name in your inventory
	label = 'Sonoran Radio', -- Label for the item in your inventory
	weight = 1, 			 -- Weight of the item in your inventory
	description = 'Communicate with others through the Sonoran Radio', -- Description of the item in your inventory
}
defaults.ScannerItem = {
	name = 'sonoran_radio_scanner', -- Item ID
	label = 'Sonoran Radio Scanner', -- Label for the item in your inventory
	weight = 1, -- Weight of the item in your inventory
	description = 'Listen to radio chatter with the Sonoran Radio Scanner', -- Description of the item in your inventory
}
defaults.disableRadioOnDeath = true -- Disables radio when dead
defaults.restoreRadioStateWhenAlive = true -- Restore the radio on/off status when you revive or respawn
defaults.deathDetectionMethod = 'auto' -- auto | manual | qbcore | qbox
defaults.heavySignalDegradeInWater = { -- Heavily degrade radio signal while the player is in water to mimic an IP67-rated handheld
	enabled = true, -- Set to true to enable heavy signal degrade in water
	pedInWaterDegredation = 0.6, -- Signal strength multiplier when the player is simply in water (e.g. 0.6 would reduce signal strength to 60% of normal)
	pedUnderWaterDegredation = 0.3 -- Signal strength multiplier when the player is underwater (e.g. 0.3 would reduce signal strength to 30% of normal)
}
defaults.disableAnimation = false -- Disable the radio animation if you are using a custom radio animation script
defaults.pttAnimation = {
	dictionary = 'random@arrests', -- Animation dictionary used while transmitting with the radio closed
	name = 'generic_radio_chatter' -- Animation name used while transmitting with the radio closed
}
defaults.noPhysicalCellRepeaters = false -- Set to true to hide physical cell repeaters
defaults.noPhysicalRacks = false -- Set to true to hide physical server racks
defaults.noPhysicalTowers = false -- Set to true to hide physical towers
defaults.talkSync = true -- Enable talking on the radio making you talk in game
defaults.emergencyCallCommand = '911' -- Command suffix to start or stop an emergency call (i.e. '911' == /radio 911)
defaults.showEmergencyCallHelp = true -- Show emergency call help text at top of screen when on an emergency call
defaults.luxartResourceName = 'lvc' -- Resource name for Luxart Vehicle Control (Required for siren control)
defaults.phoneResource = 'none' -- Which phone resource to utilize for 911 calls | OPTIONS: none (no phone resource) | lb-phone (https://lbscripts.com/)
defaults.enableBackgroundAudio = true -- Enable background audio for the radio when transmitting
defaults.autoPttOnPanic = {
	enabled = true, -- Enable automatic PTT when panic button is pressed
	duration = 15 -- Duration in seconds to hold PTT when panic button is pressed
}
defaults.autoOnSceneStatus = {
	enabled = true, -- Enable automatic ON_SCENE status when arriving at a waypoint created by SonoranRadio AI
	distance = 30.0, -- Distance in meters from the waypoint to trigger ON_SCENE status
	statusEnum = 4, -- Status enum for "ON_SCENE" -- See https://docs.sonoransoftware.com/cad/api-integration/api-endpoints/emergency/identifiers/unit-status for more information
	timeout = 900000 -- Time in milliseconds to timeout the auto ON_SCENE status after arriving at the waypoint
}
-- Notification Settings --
defaults.notifications = {
	type = 'auto', -- Available options: auto, native, pNotify, ox_lib, okokNotify, chat, lation_ui or custom
	notificationTitle = 'SonoranRadio', -- Notification Title for methods that support it
	-- Uncomment line below and comment line 105 if you plan to use pNotify
	-- notificationMessage = "<b>SonoranRadio</b></br>{{MESSAGE}}"
	notificationMessage = '~b~SonoranRadio~w~\n{{MESSAGE}}', -- The text of the notification
	ox_lib = { -- optional overrides
		type = 'inform',
		position = 'top-right',
		duration = 5000
	},
}

-- Default radio keybinds (players can change them in GTA settings).
-- See https://docs.fivem.net/docs/game-references/input-mapper-parameter-ids/keyboard (input parameter column) --
defaults.keybinds = {
	['toggle'] = '',
	['ptt'] = 'BACKSLASH',

	['power'] = '',
	['panic'] = '',
	['nextChannel'] = '',
	['prevChannel'] = '',
	['talkAnim'] = '',
	['nextGroup'] = '',
	['prevGroup'] = '',
	['volUp'] = '',
	['volDown'] = '',

	['toggleAutoCallouts'] = '',
	['toggleGeoSwitch'] = '',
	['toggleAi'] = '',
}

-- Have the radio automatically callout pursuit locations (when toggled with the keybind)
defaults.autoCallouts = {
	enabled = true, -- Whether or not this feature is enabled
	speedUnit = 'mph', -- mph | kmh | none -- The unit of speed provided with the callout
	withPostals = false, -- Whether to include postals with the automatic callouts
	postalResource = 'nearest-postal',
}

-- Geo-Channel Settings --
defaults.geoChannels = {
	enabled = true,
	command = 'sonradgeoswitch', -- command to toggle geo-channel switching | e.g. /sonradgeoswitch
	friendlyCommand = 'geoswitch', -- friendly subcommand of the /radio command to toggle geo-channel switching | e.g. / radio geoswitch
	acePermission = '', -- ACE permission required to use disable geo-channel switching | Leave blank to allow all users
	showNotifications = true, -- Show notifications when geo-channel switching is enabled/disabled
	permRefreshMs = 15000
}

-- Custom radio frames are managed in the Radio web panel's customization menu.
-- Frame permission defaults for new configurations. Backend frames use 'frame:<frame id>'.
defaults.frames = {
	permissionMode = 'none', -- ace, qbcore, qbox, esx or none
	adminPermission = 'sonoranradio.admin', -- ACE permission required to use admin commands
	departments = {
		['sahp'] = {
			label = 'San Andreas Highway Patrol',
			permissions = {
				jobs = { -- Jobs that can use this department
					['police'] = {
						grades = { -- Job grades that can use this department
							1,
							2,
							3
						}
					}
				},
				ace = { -- ACE permissions used only in ACE permission mode
					'sonoranradio.sahp'
				}
			},
			-- Backend community frame IDs
			allowedFrames = {
				'frame:1'
			}
		}
	}
}

-- Enable mobile repeaters
defaults.enableVehicleRepeaters = true
-- Mobile repeater vehicles are configured from /radiomenu and saved in
-- mobileRepeaters.json. Existing defaults.repeaterVehicleSpawncodes entries are
-- imported automatically once, then managed by the menu.

defaults.radioJammers = {
	enabled = true, -- Enable or disable radio jammers
	menuCommand = 'jammers', -- Subcommand to open the jammers menu | e.g. /sonoranradio jammers
	toggleRange = 3.0, -- Distance in meters required to toggle a jammer on/off
	permissionMode = 'none', -- ace, qbcore, esx or none
	acePermission = 'sonoranradio.jammers', -- ACE permission required to use jammers
	allowedJobs = { -- Jobs that can use jammers | Requires permission mode to be set to 'qbcore' or 'esx'
		['hacker'] = {
			grades = { -- Job grades that can use jammers
				1,
				2,
				3
			}
		}
	},
	jammers = {
		-- Define jammers here
		-- Example:
		{
			name = 'Hand Held Jammer', -- Name of the jammer
			model = 'm23_2_prop_m32_hackdevice_01a', -- Model name for the jammer
			offModel = 'm23_2_prop_m32_hackdevice_01a', -- Model name for the jammer when off | Optional
			range = 25, -- Range of the jammer in meters
			strength = 0.5, -- Strength of the jammer (0.0 to 1.0)
			permission = 'sonoranradio.jammer_handheld', -- ACE permission required to use this jammer | Optional
			-- If permission is not set, the jammer will be available to all players that can access the jammers menu
			type = 'handheld', -- Type of jammer (handheld or static)
			itemName = 'sonoran_radio_jammer_handheld', -- Item name for the jammer (if defaults.enforceRadioItem is true)
			poweredItemName = 'sonoran_radio_jammer_handheld_on' -- Optional item that replaces the base item while the jammer is powered on
		},
		{
			name = 'Suitcase Jammer', -- Name of the jammer
			model = 'ch_prop_ch_mobile_jammer_01x', -- Model name for the jammer
			offModel = 'ch_prop_ch_mobile_jammer_01x', -- Model name for the jammer when off | Optional
			range = 100, -- Range of the jammer in meters
			strength = 0.8, -- Strength of the jammer (0.0 to 1.0)
			permission = '', -- ACE permission required to use this jammer | Optional
			-- If permission is not set, the jammer will be available to all players that can access the jammers menu
			type = 'static', -- Type of jammer (handheld or static)
			itemName = 'sonoran_radio_jammer_suitcase' -- Item name for the jammer (if defaults.enforceRadioItem is true)
		},
		{
			name = 'Case Jammer', -- Name of the jammer
			model = 'h4_prop_h4_jammer_01a', -- Model name for the jammer
			offModel = 'h4_prop_h4_jammer_01a', -- Model name for the jammer when off | Optional
			range = 200, -- Range of the jammer in meters
			strength = 1.0, -- Strength of the jammer (0.0 to 1.0)
			permission = '', -- ACE permission required to use this jammer | Optional
			-- If permission is not set, the jammer will be available to all players that can
			type = 'static', -- Type of jammer (handheld or static)
			itemName = 'sonoran_radio_jammer_case' -- Item name for the jammer (if defaults.enforceRadioItem is true)
		},
		{
			name = 'Satelite Jammer', -- Name of the jammer
			model = 'm23_2_prop_m32_jammer_01a', -- Model name for the jammer
			offModel = 'm23_2_prop_m32_jammer_01a', -- Model name for the jammer when off | Optional
			range = 300, -- Range of the jammer in meters
			strength = 1.0, -- Strength of the jammer (0.0 to 1.0)
			permission = '', -- ACE permission required to use this jammer | Optional
			-- If permission is not set, the jammer will be available to all players that can
			type = 'static', -- Type of jammer (handheld or static)
			itemName = 'sonoran_radio_jammer_satelite' -- Item name for the jammer (if defaults.enforceRadioItem is true)
		}
	}
}

return defaults
