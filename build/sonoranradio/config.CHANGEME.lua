Config = {}

Config.comId = 'YOUR COMMUNITY ID' -- IMPORTANT set your Community ID here! https://sonoran.link/radioconfig
Config.apiKey = 'YOUR API KEY' -- IMPORTANT set your API Key here! https://sonoran.link/radioconfig
Config.radioUrl = 'https://sonoranradio.com' -- DO NOT CHANGE FROM 'https://sonoranradio.com' UNLESS YOU KNOW WHAT YOU ARE DOING (Developer)
Config.apiUrl = 'https://api.sonoranradio.com/' -- DO NOT CHANGE FROM 'https://api.sonoranradio.com/' UNLESS YOU KNOW WHAT YOU ARE DOING (Developer)
Config.overridePushUrl = '' -- Override the automatic resolution of a pushUrl -- change to 'http://ip:port/sonoranradio/events' ONLY IF you receive ERR-101
Config.debug = false
Config.allowUpdateWithPlayers = true
Config.enableCanary = false
Config.allowAutoUpdate = true
Config.defaultSkinId = nil -- Configure the default skin for the radio (e.g. 'default', 'hi-vis')
Config.defaultEscapeMode = 'keep' -- keep | hide | transmit_only -- Default escape mode for the radio (player can change this in the settings)
Config.chatter = true -- Hear chatter from other players if their radio is on
Config.towerRepairTimer = 20 -- Time in seconds to repair towers
Config.rackRepairTimer = 15  -- Time in seconds to repair server racks
Config.antennaRepairTimer = 15 -- Time in seconds to repair cell repeater antennas
Config.acePermSync = false -- Sync radio community auto-approval and permissions with ace permissions
Config.acePermsForServerRepair = false -- Restrict repairs for servers to an ace permission
Config.acePermsForTowerRepair = false -- Restrict repairs for towers to an ace permission
Config.acePermsForAntennaRepair = false -- Restrict repairs for cell repeater antennas to an ace permission
Config.acePermsForScanners = false -- Restrict using the scanner to an ace permission
Config.acePermsForRadio = false -- Restrict usage of the radio to an ace permission
Config.acePermsForRadioGuests = false -- Restrict users joining the radio as a guest to an ace permission
Config.acePermsForRadioUsers = false -- Restrict usage of /radiousers to an ace permission
Config.enforceRadioItem = false
Config.RadioItem = {		 -- Note: Changes to this item will require a server restart to take effect
	name = 'sonoran_radio',  -- Item name in your inventory
	label = 'Sonoran Radio', -- Label for the item in your inventory
	weight = 1, 			 -- Weight of the item in your inventory
	description = 'Communicate with others through the Sonoran Radio', -- Description of the item in your inventory
}
Config.ScannerItem = {
	name = 'sonoran_radio_scanner', -- Item ID
	label = 'Sonoran Radio Scanner', -- Label for the item in your inventory
	weight = 1, -- Weight of the item in your inventory
	description = 'Listen to radio chatter with the Sonoran Radio Scanner', -- Description of the item in your inventory
}
Config.disableRadioOnDeath = true -- Disables radio when dead
Config.restoreRadioStateWhenAlive = true -- Restore the radio on/off status when you revive or respawn
Config.deathDetectionMethod = 'auto' -- auto | manual | qbcore | qbox
Config.disableAnimation = false -- Disable the radio animation if you are using a custom radio animation script
Config.noPhysicalCellRepeaters = false -- Set to true to hide physical cell repeaters
Config.noPhysicalRacks = false -- Set to true to hide physical server racks
Config.noPhysicalTowers = false -- Set to true to hide physical towers
Config.talkSync = true -- Enable talking on the radio making you talk in game
Config.emergencyCallCommand = '911' -- Command suffix to start or stop an emergency call (i.e. '911' == /radio 911)
Config.showEmergencyCallHelp = true -- Show emergency call help text at top of screen when on an emergency call
Config.luxartResourceName = 'lvc' -- Resource name for Luxart Vehicle Control (Required for siren control)
Config.phoneResource = 'none' -- Which phone resource to utilize for 911 calls | OPTIONS: none (no phone resource) | lb-phone (https://lbscripts.com/)
Config.enableBackgroundAudio = true -- Enable background audio for the radio when transmitting
Config.autoPttOnPanic = {
	enabled = true, -- Enable automatic PTT when panic button is pressed
	duration = 15 -- Duration in seconds to hold PTT when panic button is pressed
}
-- Notification Settings --
Config.notifications = {
	type = 'auto', -- Available options: auto, native, pNotify, ox_lib, okokNotify, chat, or custom
	notificationTitle = 'SonoranRadio', -- Notification Title for methods that support it
	-- Uncomment line below and comment line 105 if you plan to use pNotify
	-- notificationMessage = "<b>SonoranRadio</b></br>{{MESSAGE}}"
	notificationMessage = '~b~SonoranRadio~w~\n{{MESSAGE}}', -- The text of the notification
	custom = function(notification) -- Custom notification function, only used if type is set to custom
		Utilities.Logging.logDebug('Custom notification function called with notification: ' .. notification)
		exports.pNotify:SendNotification({
			['type'] = 'info',
			['text'] = '<b style=\'color:blue\'>SonoranRadio</b><br/>Notification: ' .. notification .. ''
		})
	end
}
-- Customize Radio Guest Display Names
Config.getGuestDisplayName = function(source)
	-- return ('Guest %s'):format(source)
	return nil
end

-- Default radio keybinds (these can be changed in GTA settings)                                                --
-- See https://docs.fivem.net/docs/game-references/input-mapper-parameter-ids/keyboard (input parameter column) --
Config.keybinds = {
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
	['toggleGeoSwitch'] = ''
	['toggleAi'] = '',
}

-- Have the radio automatically callout pursuit locations (when toggled with the keybind)
Config.autoCallouts = {
	enabled = true, -- Whether or not this feature is enabled
	speedUnit = 'mph', -- mph | kmh | none -- The unit of speed provided with the callout
	withPostals = false, -- Whether to include postals with the automatic callouts
	postalResource = 'nearest-postal',
}

-- Geo-Channel Settings --
Config.geoChannels = {
	enabled = true,
	command = 'sonradgeoswitch', -- command to toggle geo-channel switching | e.g. /sonradgeoswitch
	friendlyCommand = 'geoswitch', -- friendly subcommand of the /radio command to toggle geo-channel switching | e.g. / radio geoswitch
	acePermission = '', -- ACE permission required to use disable geo-channel switching | Leave blank to allow all users
	showNotifications = true -- Show notifications when geo-channel switching is enabled/disabled
}

-- Radio Item Settings --
Config.frames = {
	permissionMode = 'none', -- ace, qbcore, esx or none
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
				ace = { -- ACE Permissions that can use this department | ONLY EFFECTIVE IN ACE PERMISSION MODE
					'sonoranradio.sahp'
				}
			},
			-- Radio frames that can be used by this department
			allowedFrames = {
				'default',
				'signalpro',
				'voxguard',
				'hi-vis'
			}
		}
	}
}

-- Enable mobile repeaters
Config.enableVehicleRepeaters = true
-- Mobile repeater keybinds
Config.mobileRepeaterKeybind = {
	mapperType = 'keyboard', -- See: https://docs.fivem.net/docs/game-references/input-mapper-parameter-ids/
	map = 'g', -- See: https://docs.fivem.net/docs/game-references/input-mapper-parameter-ids/
	label = 'Toggle Radio Repeater'
}
-- Mobile repeater spawncodes
Config.repeaterVehicleSpawncodes = {
	{
		model = 'police',
		label = 'Police Vehicle',
		range = 200
	},
	{
		model = 'police2',
		label = 'Police Vehicle',
		range = 200
	}
}

Config.radioJammers = {
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
			itemName = 'sonoran_radio_jammer_handheld', -- Item name for the jammer (if Config.enforceRadioItem is true)
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
			itemName = 'sonoran_radio_jammer_suitcase' -- Item name for the jammer (if Config.enforceRadioItem is true)
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
			itemName = 'sonoran_radio_jammer_case' -- Item name for the jammer (if Config.enforceRadioItem is true)
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
			itemName = 'sonoran_radio_jammer_satelite' -- Item name for the jammer (if Config.enforceRadioItem is true)
		}
	}
}
