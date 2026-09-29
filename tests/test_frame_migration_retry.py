"""Exercise FiveM's legacy frame migration and retry behavior with Lua stubs."""
import unittest
from pathlib import Path

from lupa import LuaRuntime


SOURCE = (Path(__file__).resolve().parents[1] / "lua/sv_changeFrames.lua").read_text()


class FrameMigrationRetryTests(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime()
        self.lua.execute("""
            Config = { frames = { permissionMode = 'none' } }
            now = 1000
            os.time = function() return now end
            getCount, uploadCount, migrationCount, archiveCount = 0, 0, 0, 0
            failGetAt = -1
            scan = { exists = true, errors = {}, skins = {{
                legacySkinId = 'custom', name = 'Custom',
                images = {{ source = 'portable.png', resourcePath = 'skins/custom/portable.png', fileName = 'portable.png', contentType = 'image/png' }},
                frames = {{ type = 'portable', body = { image = 'portable.png', width = 20 }, controls = {}, screen = { style = 'modern' } }}
            }} }
            backendResponse = { frames = {} }
            json = { decode = function(value) return value end, encode = function() return '{}' end }
            exports = { sonoranradio = {
                GetAvailableFrames = function() return scan.exists and {'custom'} or {} end,
                GetLegacySkinConfigs = function() return scan end,
                ArchiveLegacySkins = function()
                    archiveCount = archiveCount + 1
                    scan.exists = false
                    return { success = true, path = '/resource/skins_old' }
                end
            } }
            GetCurrentResourceName = function() return 'sonoranradio' end
            GetResourcePath = function() return '/resource' end
            LoadResourceFile = function() return 'image bytes' end
            GetPlayers = function() return {} end
            TriggerClientEvent = function() end
            warnLog = function() end
            infoLog = function() end
            debugLog = function() end
            errorLog = function(message) error(message) end
            performApiRequest = function(data, endpoint, callback)
                if endpoint == 'GET-FRAMES' then
                    getCount = getCount + 1
                    callback(backendResponse, getCount ~= failGetAt)
                elseif endpoint == 'UPLOAD-FRAME-IMAGE' then
                    uploadCount = uploadCount + 1
                    callback({ url = 'https://assets.test/portable.png' }, true)
                elseif endpoint == 'MIGRATE-FRAMES' then
                    migrationCount = migrationCount + 1
                    backendResponse = { frames = {{
                        id = 4, name = 'Custom', legacySkinId = 'custom',
                        body = data.skins[1].frames[1].body, controls = {}, screen = { style = 'modern' }
                    }} }
                    callback({ complete = true }, true)
                else error('unexpected endpoint ' .. tostring(endpoint)) end
            end
            CreateThread = function(fn) resourceThread = coroutine.create(fn) end
            TriggerEvent = function() end
            Wait = function(ms) coroutine.yield(ms) end
        """)
        self.lua.execute(SOURCE)

    def start(self):
        self.lua.execute("""
            local ok, delay = coroutine.resume(resourceThread)
            assert(ok and delay == 0)
            ok, delay = coroutine.resume(resourceThread)
            assert(ok and delay == 1000)
            ok, delay = coroutine.resume(resourceThread)
            assert(ok and delay == 30000)
        """)

    def test_migration_uploads_verifies_and_archives(self):
        self.start()
        self.lua.execute("""
            assert(uploadCount == 1 and migrationCount == 1 and archiveCount == 1)
            assert(getBackendFrameAliases().custom == 'frame:4')
            assert(isKnownFrame('custom'))
        """)

    def test_failed_verification_retries_without_reuploading(self):
        self.lua.execute("failGetAt = 2")
        self.start()
        self.lua.execute("""
            assert(uploadCount == 1 and migrationCount == 1 and archiveCount == 0)
            assert(scan.exists)
            now = 1300
            local ok, delay = coroutine.resume(resourceThread)
            assert(ok and delay == 30000)
            assert(uploadCount == 1 and migrationCount == 1 and archiveCount == 1)
        """)

    def test_api_outage_preserves_cache_until_refresh_recovers(self):
        self.lua.execute("""
            scan.exists = false
            backendResponse = { frames = {{ id = 7, body = { image = 'https://assets.test/radio.png' }, controls = {}, screen = {} }} }
        """)
        self.start()
        self.lua.execute("""
            assert(isKnownFrame('frame:7'))
            failGetAt = getCount + 1
            backendResponse = { frames = {{ id = 8, body = {}, controls = {}, screen = {} }} }
            local ok, delay = coroutine.resume(resourceThread)
            assert(ok and delay == 30000)
            assert(isKnownFrame('frame:7') and not isKnownFrame('frame:8'))
            now = now + 30
            ok, delay = coroutine.resume(resourceThread)
            assert(ok and delay == 30000)
            assert(isKnownFrame('frame:8'))
        """)


if __name__ == "__main__":
    unittest.main()
