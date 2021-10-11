-- DEVELOPMENT FXMANIFEST--

-- MAKE CHANGES TO BUILD\fxmanifest.lua --




-- required fxmanifest stuff
fx_version 'cerulean'
game 'gta5'

author 'Sonoran Software Systems LLC'
description 'Sonoran Radio FiveM Integration'
version '1.0.6'

server_scripts {
    'config.lua',
    'sv.lua',
    'update/unzip.js',
    'update/updater.lua'
}

-- setup for nui
files {
    'dist/**/*',
    'static/**/*'
} 
ui_page 'dist/ui.html'

-- build webpack page automatically when resource is started for the first time
dependencies {'yarn', 'webpack'}
webpack_config 'webpack.config.js'

client_script 'cl.lua'
