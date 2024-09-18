fx_version 'cerulean'
games { 'gta5', 'rdr3' }

rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

--[[ Resource Information ]]--
name         'xsound'
version      '1.4.3'

ui_page "html/index.html"

files {
	"html/index.html",

	"html/scripts/listener.js",
	"html/scripts/SoundPlayer.js",
	"html/scripts/functions.js",

	"html/sounds/*.ogg",
	"html/sounds/*.mp3",
}
