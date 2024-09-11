Config = {}

Config.comId = 'c6b14624-2396-46f8-b2dc-72318454e819'
Config.apiKey = 'c7d748d9-0184-458a-bc05-d0a9c53d2122'
Config.debug = false -- PER MAX: NEVER set debug to enabled by default on QA. Please manually edit config file using SFTP or https://game.sonoranservers.com
Config.radioUrl = 'https://radio.dev.sonoransoftware.com'
Config.apiUrl = 'https://radioapi.dev.sonoransoftware.com/'
Config.allowUpdateWithPlayers = true
Config.enableCanary = false
Config.allowAutoUpdate = false
Config.chatter = true
Config.towerRepairTimer = 20 -- Time in seconds to repair towers
Config.rackRepairTimer = 15  -- Time in seconds to repair server racks
Config.antennaRepairTimer = 15 -- Time in seconds to repair cell repeater antennas
Config.acePermsForServerRepair = false -- Restrict repairs for servers to an ace permission
Config.acePermsForTowerRepair = false -- Restrict repairs for towers to an ace permission
Config.acePermsForAntennaRepair = false -- Restrict repairs for cell repeater antennas to an ace permission
Config.acePermsForRadio = false -- Restrict usage of the radio to an ace permission
Config.acePermsForRadioUsers = false -- Restrict usage of the radio users to an ace permission
Config.enforceRadioItem = false
Config.disableRadioOnDeath = true
Config.restoreRadioStateWhenAlive = true -- Restore the radio on/off status when you revive or respawn
Config.deathDetectionMethod = 'auto' -- auto | manual | qbcore
Config.disableAnimation = false -- Disable the radio animation if you are using a custom radio animation script
Config.noPhysicalCellRepeaters = false -- Set to true to disable physical cell repeaters
Config.noPhysicalRacks = false -- Set to true to disable physical server racks
Config.noPhysicalTowers = false -- Set to true to disable physical towers
Config.talkSync = true -- Enable talking on the radio making you talk in game

-- Notification Settings --
Config.notifications = {
	type = 'native', -- Available options: native, pNotify, okokNotify, or custom
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

-- Radio Item Settings --
Config.frames = {
	permissionMode = "qbcore",
	adminPermission = 'sonoranradio.admin', -- ACE permission required to use admin commands
	departments = {
		['SAHP'] = {
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

-- Only Run This on Client
if not IsDuplicityVersion() then
	RegisterNetEvent('SonoranRadio::API:PlayerDeath', function(playerid)
		TriggerEvent('SonoranRadio::PlayerDeath') -- This event will kill the player
	end)
	RegisterNetEvent('SonoranRadio::API:PlayerRevive', function(playerid)
		TriggerEvent('SonoranRadio::PlayerRevive') -- This event will revive the player
	end)
end

-- Enable mobile repeaters
Config.enableVehicleRepeaters = true
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
