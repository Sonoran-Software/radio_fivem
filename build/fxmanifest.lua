-- required fxmanifest stuff
fx_version 'cerulean'
game 'gta5'

author 'Sonoran Software Systems LLC'
description 'Sonoran Radio FiveM Integration'
version '1.0.5'

server_scripts {
    'config.lua',
    'update/unzip.js',
    'update/updater.lua'
}

-- setup for nui
files {
    'html/**/*',
    'static/**/*'
} 
ui_page 'html/ui.html'

client_script 'cl.lua'
