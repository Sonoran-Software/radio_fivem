"""Run with: python -m unittest discover -s tests (requires lupa)."""
from pathlib import Path
import unittest

from lupa import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]


class FrameCacheTests(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime()
        self.lua.execute('''
            Config = { frames = { permissionMode = 'none' } }
            now = 1000
            os.time = function() return now end
            requests = 0
            responseSuccess = true
            response = { frames = {{ id = 1, body = {}, screen = {} }} }
            sent = {}
            exports = { sonoranradio = {
                GetAvailableFrames = function() return {'default'} end
            } }
            GetResourcePath = function() return '/resource' end
            GetPlayers = function() return {'42'} end
            TriggerClientEvent = function(name, player, frames, definitions)
                table.insert(sent, {name = name, player = player, frames = frames, definitions = definitions})
            end
            warnLog = function() end
            errorLog = function(message) error(message) end
            performApiRequest = function(_, endpoint, callback)
                assert(endpoint == 'GET-FRAMES')
                requests = requests + 1
                callback(response, responseSuccess)
            end
            CreateThread = function(fn) refreshThread = coroutine.create(fn) end
            Wait = function(ms) coroutine.yield(ms) end
        ''')
        self.lua.execute((ROOT / 'lua/sv_changeFrames.lua').read_text())

    def test_cache_reads_never_fetch_even_when_refresh_is_due(self):
        self.lua.execute('''
            assert(#checkFramePermissions(42) == 1)
            assert(#getAllAvailableFrames() == 1)
            assert(next(getBackendFrameDefinitions()) == nil)
            assert(not isKnownFrame('frame:1'))
            assert(requests == 0)
            local ok, delay = coroutine.resume(refreshThread)
            assert(ok and delay == 1000)
            ok, delay = coroutine.resume(refreshThread)
            assert(ok and delay == 300000 and requests == 1)
            now = now + 1000
            assert(#checkFramePermissions(42) == 2)
            assert(#getAllAvailableFrames() == 2)
            assert(getBackendFrameDefinitions()['frame:1'])
            assert(isKnownFrame('frame:1'))
            assert(requests == 1)
            assert(sent[1].player == 42 and sent[1].definitions['frame:1'])
        ''')

    def test_failed_or_invalid_refresh_retains_cache_and_next_poll_recovers(self):
        self.lua.execute('''
            assert(coroutine.resume(refreshThread))
            assert(coroutine.resume(refreshThread))
            responseSuccess = false
            now = now + 300
            assert(coroutine.resume(refreshThread))
            assert(requests == 2 and isKnownFrame('frame:1') and #sent == 1)
            responseSuccess = true
            response = {}
            now = now + 300
            assert(coroutine.resume(refreshThread))
            assert(requests == 3 and isKnownFrame('frame:1') and #sent == 1)
            response = {frames = {{id = 2, body = {}, screen = {}}}}
            now = now + 300
            assert(coroutine.resume(refreshThread))
            assert(requests == 4 and isKnownFrame('frame:2') and not isKnownFrame('frame:1'))
            assert(#sent == 2)
        ''')

    def test_authorization_keeps_original_connection_id(self):
        source = (ROOT / 'lua/sv_main.lua').read_text()
        start = source.index("RegisterNetEvent('SonoranRadio::CheckPermissions')")
        end = source.index('\nfunction validFrame', start)
        self.lua.execute('''
            RegisterNetEvent = function() end
            AddEventHandler = function(_, fn) permissionHandler = fn end
            sendGeoPerms = function(player) assert(player == 42) end
            -- Simulate a helper clearing the global event source after an await.
            checkFramePermissions = function(player)
                assert(player == 42)
                source = 0
                return {'default'}
            end
        ''')
        self.lua.execute(source[start:end])
        self.lua.execute('''
            source = 42
            permissionHandler()
            assert(#sent == 5)
            for _, event in ipairs(sent) do assert(event.player == 42) end
            assert(requests == 0)
        ''')


if __name__ == '__main__':
    unittest.main()
