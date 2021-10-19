-- Release fxmanifest.lua --
fx_version 'cerulean'
game 'gta5'

author 'Sonoran Software Systems LLC'
description 'Sonoran Radio FiveM Integration'
version '1.0.6'

shared_script 'config.lua'

server_scripts {
    'lua/**/sv_*.lua',
    'update/unzip.js',
    'update/updater.lua'
}

client_script 'lua/**/cl_*.lua'

-- setup for nui
files {
    'html/**/*',
    'static/**/*'
} 
ui_page 'html/ui.html'
