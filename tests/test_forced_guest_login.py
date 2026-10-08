"""Run with: python -m unittest discover -s tests (requires lupa)."""
from pathlib import Path
import unittest

from lupa import LuaRuntime


ROOT = Path(__file__).resolve().parents[1]


class ForcedGuestLoginTests(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime()
        self.lua.execute("""
            Config = {
                comId = 'community', serverId = 'room',
                forceGuestLogin = true, acePermSync = false,
                acePermsForRadio = true, acePermsForRadioGuests = true,
            }
            source = 42
            ace = {
                ['sonoranradio.use'] = true,
                ['sonoranradio.guest'] = true,
                ['sonoranradio.admin'] = true,
                ['sonoranradio.channel.7'] = true,
            }
            IsPlayerAceAllowed = function(src, permission)
                assert(src == 42)
                return ace[permission] == true
            end
            handlers = {}
            RegisterNetEvent = function(name, fn) handlers[name] = fn end
            AddEventHandler = function() end
            TriggerClientEvent = function(name, player, token, displayName)
                response = {name = name, player = player, token = token, displayName = displayName}
            end
            client = {
                createGuestTokenV2 = function(_, payload)
                    request = payload
                    return { success = true, data = { guestToken = 'guest-token' } }
                end,
                getCommunityChannelsV2 = function()
                    return { success = true, data = { channels = {
                        { id = 7, displayName = 'Fire', visibility = 'private' },
                        { id = 8, displayName = 'Police', visibility = 'private' },
                    } } }
                end,
            }
            getSonoranRadioClient = function() return client end
            GetPlayerName = function() return 'Player' end
        """)
        self.lua.execute((ROOT / "lua/sv_permapi.lua").read_text())

    def test_forced_guest_receives_ace_permissions_without_account_sync(self):
        self.lua.execute("""
            handlers['SonoranRadio::CreateGuestToken']()
            assert(request.serverId == 'community' and request.roomId == 'room')
            assert(request.permission == 1)
            assert(#request.profilePerms == 2)
            assert(request.profilePerms[1].profileId == 7 and request.profilePerms[1].canJoin)
            assert(request.profilePerms[2].profileId == 8 and not request.profilePerms[2].canJoin)
            assert(response.name == 'SonoranRadio::RadioGuestToken')
            assert(response.player == 42 and response.token == 'guest-token')
        """)

    def test_radio_and_guest_ace_gates_block_token_creation(self):
        self.lua.execute("""
            ace['sonoranradio.use'] = false
            handlers['SonoranRadio::CreateGuestToken']()
            assert(request == nil)
            ace['sonoranradio.use'] = true
            ace['sonoranradio.guest'] = false
            handlers['SonoranRadio::CreateGuestToken']()
            assert(request == nil)
        """)

    def test_normal_mode_keeps_existing_guest_permission_behavior(self):
        self.lua.execute("""
            Config.forceGuestLogin = false
            handlers['SonoranRadio::CreateGuestToken']()
            assert(request.permission == 0)
            assert(#request.profilePerms == 0)
        """)


if __name__ == "__main__":
    unittest.main()
