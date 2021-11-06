-- !!THIS IS THE DEVELOPMENT MANIFEST!! --

-- PRODUCTION MANIFEST IS LOCATED HERE; --
-- ./build/sonoranradio/fxmanifest.lua	--

fx_version 'cerulean'
game 'gta5'

data_file 'DLC_ITYP_REQUEST' 'stream/prop_radio_tower.ytyp'

shared_script 'config.lua'
server_script 'lua/**/sv_*.lua'
client_script 'lua/**/cl_*.lua'

-- setup for nui
files {
    'stream/*',
    'dist/**/*',
    'static/**/*'
} 
ui_page 'dist/ui.html'

-- build webpack page automatically when resource is started for the first time
dependencies {'yarn', 'webpack'}
webpack_config 'webpack.config.js'
