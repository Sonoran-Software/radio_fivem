"""Exercise earpiece sync before and after an empty configuration loads."""

from pathlib import Path
import unittest

from lupa import LuaRuntime


SOURCE = (Path(__file__).resolve().parents[1] / "lua/sv_chatter.lua").read_text()


class ChatterConfigSyncTests(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime()
        self.lua.execute("""
            Config = {chatter = true}
            chatterConfig = nil
            handlers = {}
            events = {}
            sent = {}
            Citizen = {CreateThread = function() end}
            RegisterNetEvent = function(name, handler) handlers[name] = handler end
            AddEventHandler = function(name, handler) events[name] = handler end
            GetPlayerName = function(playerId) return 'Player ' .. playerId end
            TriggerClientEvent = function(name, playerId, config)
                table.insert(sent, {name = name, playerId = playerId, config = config})
            end
            Wait = function() error('earpiece sync must not poll') end
        """)
        self.lua.execute(SOURCE)

    def test_empty_config_flushes_waiting_players_without_polling(self):
        self.lua.execute("""
            for playerId = 1, 40 do
                source = playerId
                handlers['Chatter:clientChatterSync']()
                handlers['Chatter:clientChatterSync']()
            end
            assert(#sent == 0)
            chatterConfig = {}
            events['SonoranRadio::ChatterConfigReady']()
            assert(#sent == 40)
            for _, event in ipairs(sent) do
                assert(event.name == 'Chatter:clientChatterSync_c')
                assert(event.config == chatterConfig and #event.config == 0)
            end
            source = 41
            handlers['Chatter:clientChatterSync']()
            assert(#sent == 41 and sent[41].playerId == 41)
        """)

    def test_disconnected_player_is_not_sent_pending_config(self):
        self.lua.execute("""
            source = 12
            handlers['Chatter:clientChatterSync']()
            events['playerDropped']()
            chatterConfig = {}
            events['SonoranRadio::ChatterConfigReady']()
            assert(#sent == 0)
        """)


if __name__ == "__main__":
    unittest.main()
