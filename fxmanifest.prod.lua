-- Release fxmanifest.lua --
fx_version 'cerulean'
game 'gta5'

author 'Sonoran Software Systems LLC'
description 'Sonoran Radio FiveM Integration'
version '$RESOURCE_VERSION'

shared_scripts {
    'config.lua',
    'lua/**/sh_*.lua'
}

server_scripts {
    'lua/**/sv_*.lua',
    'lua/update/unzip.js',
    'lua/update/updater.lua',
    'lua/**/sv_*.js',
}

client_scripts {
    'lua/**/cl_*.lua'
}

-- setup for nui
files {
    'dist/**/*',
    'skins/**/*',
    'miniradio/**/*',
}
ui_page 'dist/ui.html'
ui_page 'miniradio/miniradio.html'
-- setup for streamed files
files {
    'data/vehicles.meta',
    'data/carvariations.meta',
}
data_file 'VEHICLE_METADATA_FILE' 'data/vehicles.meta'
data_file 'VEHICLE_VARIATION_FILE' 'data/carvariations.meta'
data_file 'DLC_ITYP_REQUEST' 'stream/prop_radio_tower.ytyp'
