"""Run with: python -m unittest discover -s tests (requires lupa)."""
from pathlib import Path
import unittest

from lupa import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]


class FrameCacheTests(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime()
        self.lua.execute('''
            Config = { apiKey = 'test-key', frames = { permissionMode = 'none' } }
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
            threads = {}
            CreateThread = function(fn)
                local thread = coroutine.create(fn)
                table.insert(threads, thread)
                refreshThread = refreshThread or thread
            end
            pushHandlers = {}
            TriggerEvent = function(event, kind, fn)
                if event == 'sonoranradio::RegisterPushEvent' then pushHandlers[kind] = fn end
            end
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

    def test_push_refetches_without_waiting_for_poll_and_keeps_cache_on_failure(self):
        self.lua.execute("""
            assert(coroutine.resume(refreshThread))
            assert(coroutine.resume(refreshThread))
            response = {frames = {{id = 2, body = {}, screen = {}}}}
            pushHandlers.frames_updated({payload = {frames = 'ignored'}})
            assert(requests == 1) -- webhook returns before the fetch
            assert(coroutine.resume(threads[2]))
            assert(requests == 2 and isKnownFrame('frame:2') and #sent == 2)
            responseSuccess = false
            pushHandlers.frames_updated({})
            assert(coroutine.resume(threads[3]))
            assert(requests == 3 and isKnownFrame('frame:2') and #sent == 2)
        """)

    def test_push_during_fetch_queues_one_followup(self):
        self.lua.execute("""
            assert(coroutine.resume(refreshThread))
            assert(coroutine.resume(refreshThread))
            performApiRequest = function(_, _, callback)
                requests = requests + 1
                if requests == 2 then coroutine.yield('fetching') end
                callback({frames = {{id = requests, body = {}, screen = {}}}}, true)
            end
            pushHandlers.frames_updated({})
            local ok, state = coroutine.resume(threads[2])
            assert(ok and state == 'fetching')
            pushHandlers.frames_updated({})
            pushHandlers.frames_updated({})
            assert(coroutine.resume(threads[3]))
            assert(coroutine.resume(threads[4]))
            assert(requests == 2)
            assert(coroutine.resume(threads[2]))
            assert(requests == 3 and isKnownFrame('frame:3'))
        """)

    def test_webhook_requires_api_key(self):
        self.lua.execute("""
            assert(coroutine.resume(refreshThread))
            assert(coroutine.resume(refreshThread))
            RegisterNetEvent = function(_, fn) registerPush = fn end
            SetHttpHandler = function(fn) httpHandler = fn end
            json = {decode = function(data) return data end, encode = function() return '{}' end}
        """)
        self.lua.execute((ROOT / 'lua/sv_pushevents.lua').read_text())
        self.lua.execute("""
            registerPush('frames_updated', pushHandlers.frames_updated)
            local function deliver(key)
                local reply
                httpHandler({path = '/events', method = 'POST', setDataHandler = function(fn)
                    fn({key = key, type = 'frames_updated'})
                end}, {send = function(body) reply = body end})
                return reply
            end
            assert(deliver('wrong-key') == 'Bad API Key')
            assert(#threads == 1 and requests == 1)
            assert(deliver('test-key') == 'ok')
            assert(#threads == 2)
            assert(coroutine.resume(threads[2]))
            assert(requests == 2)
        """)

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
