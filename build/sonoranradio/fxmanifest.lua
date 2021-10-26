-- Release fxmanifest.lua --
fx_version 'cerulean'
game 'gta5'

author 'Sonoran Software Systems LLC'
description 'Sonoran Radio FiveM Integration'
version '1.1.1'

server_scripts {
    'config.lua',
    'lua/**/sv_*.lua',
    'lua/update/unzip.js',
    'lua/update/updater.lua'
}

client_scripts {
    'config.lua',
    'lua/**/cl_*.lua'
}

-- setup for nui
files {
    'dist/**/*',
    'static/**/*'
} 
ui_page 'dist/ui.html'
