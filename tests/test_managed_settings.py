"""Managed-settings startup and migration tests for the FiveM resource."""
import json
from pathlib import Path
import unittest

from lupa import LuaRuntime, lua_type


ROOT = Path(__file__).resolve().parents[1]
BOOTSTRAP = (ROOT / "build/sonoranradio/config.CHANGEME.lua").read_text(encoding="utf-8")
DEFAULTS = (ROOT / "lua/config/defaults.lua").read_text(encoding="utf-8")
MANAGED = (ROOT / "lua/config/managed.lua").read_text(encoding="utf-8-sig")


class ManagedSettingsTests(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime()
        self.settings = self.lua.globals()
        self.defaults = self.lua.execute(DEFAULTS)
        self.cache = None
        self.requests = []
        self.get_modes = []
        self.responses = []
        self.kvp = {}
        self.logs = []
        self.allow_write = True
        self.api_origin = "https://api.sonoranradio.com"
        self.settings.toJSON = lambda value: json.dumps(self.from_lua(value))
        self.settings.parseJSON = lambda value: self.to_lua(json.loads(value))
        self.settings.loadFile = self.load_file
        self.settings.writeCache = self.write_cache
        self.settings.getMark = self.kvp.get
        self.settings.setMark = self.kvp.__setitem__
        self.settings.doRequest = self.do_request
        self.settings.recordLog = self.logs.append
        self.lua.execute("""
            GetCurrentResourceName = function() return 'sonoranradio' end
            GetResourceMetadata = function() return '5.0.0' end
            LoadResourceFile = function(_, path) return loadFile(path) end
            GetResourceKvpString = function(key) return getMark(key) end
            SetResourceKvp = function(key, value) setMark(key, value) end
            json = {
                decode = function(data) return parseJSON(data) end,
                encode = function(value) return toJSON(value) end,
            }
            exports = { sonoranradio = {
                SaveManagedRadioSettings = function(_, value) return writeCache(value) end,
            } }
            PerformHttpRequest = function(...) doRequest(...) end
            promise = {
                new = function()
                    return { resolve = function(self, value) self.value = value end }
                end
            }
            Citizen = {
                Await = function(promise) return assert(promise.value) end,
                SetTimeout = function(_, callback) timeout = callback end,
                CreateThread = function(fn) fn() end,
            }
            print = function(line) recordLog(line) end
        """)

    def from_lua(self, value):
        if lua_type(value) != "table":
            return value
        keys = list(value.keys())
        if keys and set(keys) == set(range(1, len(keys) + 1)):
            return [self.from_lua(value[index]) for index in range(1, len(keys) + 1)]
        return {key: self.from_lua(entry) for key, entry in value.items()}

    def to_lua(self, value):
        if isinstance(value, dict):
            return self.lua.table_from({key: self.to_lua(entry) for key, entry in value.items()})
        if isinstance(value, list):
            return self.lua.table_from([self.to_lua(entry) for entry in value])
        return value

    def load_file(self, name):
        if name == "lua/config/defaults.lua":
            return DEFAULTS
        return self.cache

    def write_cache(self, value):
        self.assertNotIn("PRIVATE-KEY", value)
        self.assertNotIn("getGuestDisplayName", value)
        self.assertNotIn("portalCallbackSecret", value)
        if not self.allow_write:
            return False
        self.cache = value
        return True

    def do_request(self, url, callback, method, body, headers, options):
        self.assertTrue(url.startswith(f"{self.api_origin}/v2/servers/DEMO/rooms/"))
        self.assertEqual(headers.Authorization, "Bearer PRIVATE-KEY")
        self.assertEqual(headers["X-FiveM-Resource-Version"], "5.0.0")
        self.assertFalse(options.followLocation)
        if method == "GET":
            self.get_modes.append(headers["X-FiveM-Settings-Mode"])
        self.requests.append((method, body))
        status, value = self.responses.pop(0)
        if status == "timeout":
            self.settings.timeout()
            if value is not None:
                callback(200, json.dumps(value))
        else:
            callback(status, json.dumps(value) if value is not None else None)

    def start(self, *, managed=None, room=1, local=None):
        config = dict(comId="demo", serverId=room, apiKey="PRIVATE-KEY", **(local or {}))
        if managed is not None:
            config["managedSettings"] = managed
        self.settings.Config = self.to_lua(config)
        self.lua.execute(MANAGED)
        return self.settings.InitializeManagedRadioSettings()

    def snapshot(self, configured, revision=0, **overrides):
        settings = self.from_lua(self.defaults)
        settings.update({"defaultSkinId": None, **overrides})
        return {"schemaVersion": 1, "configured": configured, "revision": revision,
                "settings": settings}

    def test_new_server_reads_defaults_and_caches_a_scoped_copy(self):
        self.lua.execute(BOOTSTRAP)
        self.assertIn("Config.serverId = nil", BOOTSTRAP)
        self.assertEqual(set(self.settings.Config.keys()), {"comId", "apiKey"})
        self.settings.Config.comId = "demo"
        self.settings.Config.apiKey = "PRIVATE-KEY"
        self.settings.Config.serverId = 1
        self.responses = [(200, self.snapshot(False, forceGuestLogin=True))]
        self.lua.execute(MANAGED)
        self.assertTrue(self.settings.InitializeManagedRadioSettings())
        self.assertTrue(self.settings.Config.forceGuestLogin)
        self.assertEqual(self.settings.Config.apiUrl, self.api_origin + "/")
        self.assertEqual(self.settings.Config.radioUrl, "https://sonoranradio.com")
        self.assertTrue(self.settings.Config.allowAutoUpdate)
        self.assertEqual(json.loads(self.cache)["scope"]["roomId"], 1)
        self.assertIsNone(self.settings.Config.defaultSkinId)
        self.assertEqual(self.requests, [("GET", "")])
        self.assertEqual(self.get_modes, ["managed"])

    def test_bootstrap_preserves_explicit_host_overrides_and_local_notification_callback(self):
        self.api_origin = "https://staging-api.dev.sonoranradio.com"
        self.lua.execute(BOOTSTRAP)
        self.lua.execute("""
            Config.comId = 'demo'
            Config.apiKey = 'PRIVATE-KEY'
            Config.serverId = 1
            Config.apiUrl = 'https://staging-api.dev.sonoranradio.com/'
            Config.radioUrl = 'https://staging.dev.sonoranradio.com'
            Config.allowAutoUpdate = false
            Config.notifications = { custom = function() return 'portalCallbackSecret' end }
        """)
        snapshot = self.snapshot(True, 1)
        snapshot["settings"]["notifications"]["type"] = "custom"
        self.responses = [(200, snapshot)]
        self.lua.execute(MANAGED)
        self.assertTrue(self.settings.InitializeManagedRadioSettings())
        self.assertEqual(self.get_modes, ["managed"])
        self.assertEqual(self.settings.Config.apiUrl, self.api_origin + "/")
        self.assertEqual(self.settings.Config.radioUrl, "https://staging.dev.sonoranradio.com")
        self.assertFalse(self.settings.Config.allowAutoUpdate)
        self.assertEqual(self.settings.Config.notifications.custom(), "portalCallbackSecret")
        self.assertEqual(json.loads(self.cache)["scope"]["origin"], self.api_origin)

    def test_legacy_setting_preserves_opt_in_and_local_value(self):
        self.responses = [(200, self.snapshot(True, 1, chatter=True))]
        self.assertTrue(self.start(local={"chatter": False}))
        self.assertFalse(self.settings.Config.chatter)
        self.assertIsNone(self.settings.Config.allowAutoUpdate)
        self.assertIsNone(self.cache)
        self.assertEqual(self.get_modes, ["legacy"])

    def test_optional_legacy_skin_and_explicit_flag_preserve_legacy_mode(self):
        self.responses = [(200, self.snapshot(True, 1)), (200, self.snapshot(True, 1))]
        self.assertTrue(self.start(local={"defaultSkinId": "custom-skin"}))
        self.assertEqual(self.settings.Config.defaultSkinId, "custom-skin")
        self.assertTrue(self.start(managed=False))
        self.assertIsNone(self.cache)
        self.assertEqual(self.get_modes, ["legacy", "legacy"])

    def test_legacy_uses_local_settings_until_migrated_then_applies_on_restart(self):
        remote = self.snapshot(True, 1, defaultEscapeMode="hide")
        self.responses = [(200, self.snapshot(False)), (200, self.snapshot(False)),
                          (200, remote), (200, remote)]
        self.assertTrue(self.start(local={"defaultEscapeMode": "hide", "forceGuestLogin": True}))
        self.assertEqual(self.settings.Config.defaultEscapeMode, "hide")
        self.assertIsNone(self.cache)
        self.lua.execute("""
            Config.getGuestDisplayName = function() return 'portalCallbackSecret' end
            Config.notifications = {
                type = 'custom',
                custom = function() return 'portalCallbackSecret' end,
                apiKey = 'PRIVATE-KEY',
            }
            Config.radioJammers = {
                allowedJobs = { hacker = { 1, 3 } },
            }
        """)
        self.settings.MigrateRadioSettings()
        self.assertEqual([method for method, _ in self.requests], ["GET", "GET", "POST", "GET"])
        uploaded = json.loads(self.requests[2][1])["settings"]
        self.assertEqual(uploaded["notifications"], {"type": "custom"})
        self.assertEqual(uploaded["radioJammers"]["allowedJobs"], {"hacker": {"grades": [1, 3]}})
        self.assertTrue(uploaded["forceGuestLogin"])
        self.assertNotIn("apiKey", uploaded)
        self.assertNotIn("PRIVATE-KEY", self.requests[2][1])
        self.assertTrue(self.settings.Config.forceGuestLogin, "migration must not replace running settings")
        self.assertEqual(json.loads(self.cache)["document"]["revision"], 1)
        self.responses = [(200, remote)]
        self.assertTrue(self.start(managed=False, local={"forceGuestLogin": True}))
        self.assertFalse(self.settings.Config.forceGuestLogin)
        self.assertEqual(self.settings.Config.defaultEscapeMode, "hide")
        self.assertEqual(self.get_modes, ["legacy", "legacy", "legacy", "managed"])

    def test_failed_readback_preserves_local_settings_without_claiming_success(self):
        remote = self.snapshot(True, 1)
        self.responses = [(200, self.snapshot(False)), (200, self.snapshot(False)),
                          (200, remote), (503, None)]
        self.assertTrue(self.start(local={"forceGuestLogin": True}))
        self.settings.MigrateRadioSettings()
        self.assertIsNone(self.cache)
        self.assertFalse(self.kvp)
        self.assertIn("could not be verified", self.logs[-1])

    def test_repeat_migration_never_overwrites_existing_portal_settings(self):
        remote = self.snapshot(True, 4)
        self.responses = [(200, remote), (200, remote)]
        self.assertTrue(self.start(local={"acePermsForRadio": True}))
        self.assertTrue(self.settings.Config.acePermsForRadio)
        self.assertIsNone(self.cache)
        self.settings.MigrateRadioSettings()
        self.assertEqual([method for method, _ in self.requests], ["GET", "GET"])
        self.assertEqual(json.loads(self.cache)["document"]["revision"], 4)

    def test_availability_fallback_ignores_late_response_and_wrong_room(self):
        original = self.snapshot(True, 2, acePermsForRadio=True)
        self.responses = [(200, original)]
        self.assertTrue(self.start(managed=True))
        cached_before = self.cache
        self.responses = [("timeout", self.snapshot(True, 90))]
        self.assertTrue(self.start(managed=True))
        self.assertTrue(self.settings.Config.acePermsForRadio)
        self.assertEqual(self.cache, cached_before)
        self.responses = [(503, None)]
        self.assertFalse(self.start(managed=True, room=2))

    def test_permission_denial_fails_closed_even_with_backup(self):
        self.responses = [(200, self.snapshot(True, 1))]
        self.assertTrue(self.start(managed=True))
        self.responses = [(403, None)]
        self.assertFalse(self.start(managed=True))

    def test_recreated_room_receives_authoritative_defaults(self):
        self.responses = [(200, self.snapshot(True, 2, acePermsForRadio=True))]
        self.assertTrue(self.start(managed=True))
        self.responses = [(200, self.snapshot(False, 0))]
        self.assertTrue(self.start(managed=True))
        self.assertFalse(self.settings.Config.acePermsForRadio)
        self.assertFalse(json.loads(self.cache)["document"]["configured"])

    def test_new_server_without_network_or_verified_settings_fails_closed(self):
        self.responses = [(503, None)]
        self.assertFalse(self.start(managed=True))
        self.assertIsNone(self.cache)

    def test_malformed_permission_data_cannot_replace_verified_settings(self):
        valid = self.snapshot(True, 1)
        valid["settings"]["frames"]["permissionMode"] = "ace"
        self.responses = [(200, valid)]
        self.assertTrue(self.start(managed=True))
        valid["settings"]["frames"]["permissionMode"] = "unrecognized"
        valid["settings"]["frames"]["departments"]["sahp"]["permissions"]["ace"] = "invalid"
        self.responses = [(200, valid)]
        self.assertTrue(self.start(managed=True))
        self.assertEqual(self.settings.Config.frames.permissionMode, "ace")
        malformed_cache = json.loads(self.cache)
        malformed_cache["document"] = valid
        self.cache = json.dumps(malformed_cache)
        self.responses = [(503, None)]
        self.assertFalse(self.start(managed=True))

    def test_invalid_nested_lua_callback_is_not_replaced_by_portal_source(self):
        snapshot = self.snapshot(True, 1)
        snapshot["settings"]["notifications"]["type"] = "custom"
        self.responses = [(200, snapshot)]
        self.assertTrue(self.start(managed=True))
        self.assertEqual(self.settings.Config.notifications.type, "auto")
        self.assertEqual(json.loads(self.cache)["document"]["settings"]["notifications"]["type"], "custom")


if __name__ == "__main__":
    unittest.main()
