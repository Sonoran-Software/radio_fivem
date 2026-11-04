"""Run with: python -m unittest discover -s tests (requires lupa)."""
from pathlib import Path
import unittest

from lupa import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]


class ServerRegistrationTests(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime()
        self.lua.execute("""
            Config = { apiKey = 'test-key', overridePushUrl = 'http://custom:30121/sonoranradio/events' }
            promise = { new = function()
                return { resolve = function(_, value) resolved = value end,
                         reject = function(_, reason) error(reason) end }
            end }
            Citizen = { CreateThreadNow = function(fn) fn() end }
            GetConvar = function(name, fallback)
                assert(name ~= 'sv_projectName', 'deprecated server name must not be read')
                return fallback
            end
            GetConvarInt = function(name, fallback)
                if name == 'netPort' then return 30121 end
                return convarRoom or fallback
            end
            GetResourceKvpInt = function() return savedRoom or 0 end
            SetResourceKvpInt = function(_, value) savedRoom = value end
            setSonoranRadioClientRoomId = function(value) clientRoom = value end
            GetCurrentResourceName = function() return 'sonoranradio' end
            LoadResourceFile = function() return "Config.apiKey = 'test-key'\\n" end
            SaveResourceFile = function(_, _, content) savedConfig = content; return true end
            json = { decode = function(value) return value end }
            warnLog = function() end
            print = function() end
            exports = { sonoranradio = { performApiRequest = function(_, payload, endpoint, callback)
                assert(endpoint == 'SET-SERVER-IP')
                request = payload
                callback({ roomId = payload.roomId or 1 }, true)
            end } }
        """)
        source = (ROOT / "lua/sv_main.lua").read_text()
        self.lua.execute("assert(load(...))", source)
        start = source.index("local function initConfigServerId()")
        end = source.index("\n-- this function creates/initializes", start)
        self.lua.execute(source[start:end] + "\ninitialize = initConfigServerId")

    def test_new_server_registers_without_a_name_and_saves_returned_id(self):
        self.lua.execute("""
            initialize()
            assert(request.nickname == nil and request.roomId == nil)
            assert(request.serverPort == 30121)
            assert(request.overridePushUrl == 'http://custom:30121/sonoranradio/events')
            assert(Config.init and Config.serverId == 1)
            assert(savedRoom == 1 and clientRoom == 1 and resolved == 1)
            assert(savedConfig:find('Config.serverId = 1', 1, true))
        """)

    def test_existing_server_ids_are_preserved_without_sending_a_name(self):
        for setting in ["convarRoom = 4", "Config.serverId = 4", "savedRoom = 4"]:
            with self.subTest(setting=setting):
                self.lua.execute("convarRoom = nil; Config.serverId = nil; savedRoom = nil")
                self.lua.execute(setting)
                self.lua.execute("""
                    initialize()
                    assert(request.roomId == 4 and request.nickname == nil)
                    assert(Config.init and Config.serverId == 4)
                    assert(savedRoom == 4 and clientRoom == 4 and resolved == 4)
                """)


if __name__ == "__main__":
    unittest.main()
