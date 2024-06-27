Config = {}

Config.comId = 'YOUR COMMUNITY ID' -- IMPORTANT set your API ID here! https://info.sonoranradio.com/standalone-alpha/getting-started/installing-the-in-game-resource
Config.debug = false
Config.allowUpdateWithPlayers = true
Config.enableCanary = false
Config.allowAutoUpdate = true
Config.noPhysicalTowers = false
Config.towerRepairTimer = 20
Config.rackRepairTimer = 15
Config.acePermsForRadio = false
Config.acePermsForTowerRepair = false
Config.acePermsForServerRepair = false
Config.enforceRadioItem = false
Config.disableRadioOnDeath = true
Config.restoreRadioStateWhenAlive = true -- Restore the radio on/off status when you revive or respawn
Config.deathDetectionMethod = 'auto' -- auto | manual | qbcore
Config.disableAnimation = false -- Disable the radio animation if you are using a custom radio animation script

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
	permissionMode = 'ace', -- ace, qbcore, esx or none
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
				'voxguard'
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
