function initScanners()
	local scannerSettings = { power = false, channel = 0 }
	WarMenu.CreateMenu('scannerControls', 'Scanner Controls')

	function openScanner(scannerId)
		Citizen.CreateThread(function()
			WarMenu.OpenMenu('scannerControls')
			while WarMenu.IsMenuOpened('scannerControls') do
				WarMenu.Button('Power On')
				WarMenu.Button('Next Channel')
				WarMenu.Button('Previous Channel')

				WarMenu.Display()
				Citizen.Wait(0)
			end
		end)
	end
	function openLocalScanner()
		openScanner(nil)
	end
	RegisterCommand('scanner', function()
		openLocalScanner()
	end)

	function getScannerChatterSources()
		local ped = GetPlayerPed(-1)
		return {}
	end
end
