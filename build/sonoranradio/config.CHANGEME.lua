Config = {}

Config.comId = 'YOUR COMMUNITY ID' -- IMPORTANT set your Community ID here! https://sonoran.link/radioconfig
Config.apiKey = 'YOUR API KEY' -- IMPORTANT set your API Key here! https://sonoran.link/radioconfig
Config.radioUrl = 'https://sonoranradio.com' -- DO NOT CHANGE FROM 'https://sonoranradio.com' UNLESS YOU KNOW WHAT YOU ARE DOING (Developer)
Config.apiUrl = 'https://api.sonoranradio.com/' -- DO NOT CHANGE FROM 'https://api.sonoranradio.com/' UNLESS YOU KNOW WHAT YOU ARE DOING (Developer)
Config.overridePushUrl = '' -- Override the automatic resolution of a pushUrl -- change to 'http://ip:port/sonoranradio/events' ONLY IF you receive ERR-101
Config.debug = false
Config.allowUpdateWithPlayers = false
Config.enableCanary = false
Config.allowAutoUpdate = true
-- Generated downloads include the Community ID, API key and Radio server ID.
-- Configure radio and gameplay settings in Admin > Game Integration.
-- Restart this resource after saving settings there. Keep this file server-side.
Config.managedSettings = true

-- Advanced local Lua callbacks are optional. Keep any existing implementations here.
-- Config.getGuestDisplayName = function(source) return nil end
-- Config.getRadioDisplayName = function(source) return nil end
