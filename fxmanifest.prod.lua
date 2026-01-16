-- Release fxmanifest.lua --
fx_version 'cerulean'
game 'gta5'
lua54 'yes'
author 'Sonoran Software Systems LLC'
description 'Sonoran Radio FiveM Integration'
version '$RESOURCE_VERSION'


server_script 'config.lua'
server_script 'lua/utils.js'
server_script 'lua/update/unzip.js'
server_script 'lua/update/updater.lua'

shared_script 'lua/**/sh_*.lua'
server_script 'lua/**/sv_*.lua'
client_script 'lua/**/cl_*.lua'


-- setup for nui
files {
    'dist/**/*',
    'miniradio/**/*',
    'tablet/**/*',
    'skins/**/*',
    'lua/xsound/html/**/*'
}
ui_page 'dist/ui.html'

-- setup for streamed files
files {
    'data/vehicles.meta',
    'data/carvariations.meta',
}
data_file 'VEHICLE_METADATA_FILE' 'data/vehicles.meta'
data_file 'VEHICLE_VARIATION_FILE' 'data/carvariations.meta'
data_file 'DLC_ITYP_REQUEST' 'stream/prop_radio_tower.ytyp'
