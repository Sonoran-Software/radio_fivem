local repeaters = {}
local lastLogs = {}

RegisterNetEvent('sonoranscripts::togglerepeater', function(id, repeater, pos, range)
	if id == nil then
		RegPrint('Failed to toggle repeater, ID is nil')
		return
	end
	if repeater then
		if repeaters[id] ~= nil then
			exports['sonoranradio']:updateTower(repeaters[id], nil)
			repeaters[id] = exports['sonoranradio']:createTower({
				Destruction = false,
				NotPhysical = true,
				Swankiness = 0.0,
				PropPosition = pos,
				DishStatus = {
					'alive',
					'alive',
					'alive',
					'alive'
				},
				Range = range,
				Powered = true,
				DontSaveMe = true
			})
		else
			repeaters[id] = exports['sonoranradio']:createTower({
				Destruction = false,
				NotPhysical = true,
				Swankiness = 0.0,
				PropPosition = pos,
				DishStatus = {
					'alive',
					'alive',
					'alive',
					'alive'
				},
				Range = range,
				Powered = true,
				DontSaveMe = true
			})
		end
	else
		exports['sonoranradio']:updateTower(repeaters[id], nil)
		repeaters[id] = nil
	end
end)

RegisterNetEvent('sonoranscripts::updatepos', function(id, pos, range)
	if id == nil then
		RegPrint('Failed to update repeater position, ID is nil')
		return
	end
	if repeaters[id] then
		exports['sonoranradio']:updateTower(repeaters[id], {
			Destruction = false,
			NotPhysical = true,
			Swankiness = 0.0,
			PropPosition = pos,
			DishStatus = {
				'alive',
				'alive',
				'alive',
				'alive'
			},
			Range = range,
			Powered = true,
			DontSaveMe = true
		})
	end
end)

function RegPrint(...)
	print('^5[SONRAD]^7', ...)
end
