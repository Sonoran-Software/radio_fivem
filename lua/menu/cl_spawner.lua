local state = {}
Citizen.CreateThread(function()
	WarMenu.CreateMenu('sonoranRadioMenu', 'Radio Repeater Menu')
	WarMenu.SetMenuTitleBackgroundSprite('sonoranRadioMenu', 'radio_menu_header', 'option_1')
	WarMenu.SetSubTitle('sonoranRadioMenu', 'Sonoran Software')
	WarMenu.CreateSubMenu('spawnRadioMenu', 'sonoranRadioMenu', 'Spawn Radio Repeater')
	WarMenu.SetMenuTitleBackgroundSprite('spawnRadioMenu', 'sonoran_menu_header', 'option_1')
	WarMenu.CreateSubMenu('moveRadioMenu', 'sonoranRadioMenu', 'Move Radio Repeater')
	WarMenu.SetMenuTitleBackgroundSprite('moveRadioMenu', 'sonoran_menu_header', 'option_1')
	WarMenu.CreateSubMenu('deleteRadioMenu', 'sonoranRadioMenu', 'Delete Radio Repeater')
	WarMenu.SetMenuTitleBackgroundSprite('deleteRadioMenu', 'sonoran_menu_header', 'option_1')
	while true do
		if WarMenu.IsMenuOpened('sonoranRadioMenu') then -- Main menu processing
			if WarMenu.MenuButton('Radio Repeater Spawning Menu', 'spawnRadioMenu') then
			end
			if WarMenu.MenuButton('Radio Repeater Move Menu', 'moveRadioMenu') then
			end
			if WarMenu.MenuButton('Radio Repeater Deletion Menu', 'deleteRadioMenu') then
			end
			WarMenu.Display()
		elseif WarMenu.IsMenuOpened('spawnRadioMenu') then
			spawningRadioRepeater()
			WarMenu.Display()
		elseif WarMenu.IsMenuOpened('moveRadioMenu') then
			movingRadioRepeater()
			WarMenu.Display()
		elseif WarMenu.IsMenuOpened('deleteRadioMenu') then
			deletingRadioRepeater()
			WarMenu.Display()
		end
		Wait(0)
	end
end)

function spawningRadioRepeater()
	local radioRepeaters = {
		'Cell Repeater',
		'Radio Tower',
		'Server Rack'
	}
	if WarMenu.ComboBox('Prop Type:', radioRepeaters, state.index, state.index, function(current)
		state.index = current
	end) then
		
	end
end
