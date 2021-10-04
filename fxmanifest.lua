-- DEVELOPMENT FXMANIFEST--

-- MAKE CHANGES TO BUILD\fxmanifest.lua --




-- required fxmanifest stuff
fx_version 'cerulean'
game 'gta5'

author 'Sonoran Software Systems LLC'
description 'Sonoran Radio FiveM Integration'
version '1.0.4'

server_scripts {
    'dist/test/config.lua',
    'dist/test/unzip.js',
    'dist/test/updater.lua'
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
