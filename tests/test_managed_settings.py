"""Managed-settings startup and migration tests for the FiveM resource."""
import json
from hashlib import sha256
from pathlib import Path
import unittest

from lupa import LuaRuntime, lua_type


ROOT = Path(__file__).resolve().parents[1]
BOOTSTRAP = (ROOT / "build/sonoranradio/config.CHANGEME.lua").read_text(encoding="utf-8")
DEFAULTS = (ROOT / "lua/config/defaults.lua").read_text(encoding="utf-8")
MANAGED = (ROOT / "lua/config/managed.lua").read_text(encoding="utf-8-sig")
BACKUP = (ROOT / "lua/config/backup.lua").read_text(encoding="utf-8")
BACKUP_PATH = "lua/config/.configuration-cache.json"


class ManagedSettingsTests(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime()
        self.settings = self.lua.globals()
        self.defaults = self.lua.execute(DEFAULTS)
        self.cache = None
        self.legacy_files = {}
        self.requests = []
        self.get_modes = []
        self.responses = []
        self.kvp = {}
        self.logs = []
        self.allow_write = True
        self.allow_cleanup = True
        self.archive_attempts = []
        self.config_file = "Config = { chatter = true }\n"
        self.api_origin = "https://api.sonoranradio.com"
        self.settings.toJSON = lambda value: json.dumps(self.from_lua(value))
        self.settings.parseJSON = lambda value: self.to_lua(json.loads(value))
        self.settings.loadFile = self.load_file
        self.settings.writeCache = self.write_cache
        self.settings.archiveConfig = self.archive_config
        self.settings.keyFingerprint = lambda key: sha256(key.encode()).hexdigest() if key else None
        self.settings.getMark = self.kvp.get
        self.settings.setMark = self.kvp.__setitem__
        self.settings.doRequest = self.do_request
        self.settings.recordLog = self.logs.append
        self.lua.execute((ROOT / "lua/sh_logcodes.lua").read_text(encoding="utf-8"))
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
                WriteManagedRadioConfigBackup = function(_, value) return writeCache(value) end,
                ArchiveMigratedRadioConfig = function(_, original, bootstrap) return archiveConfig(original, bootstrap) end,
                GetRadioBootstrapKeyFingerprint = function(_, key) return keyFingerprint(key) end,
            } }
            VerifyRadioPlacementMigration = function()
                local placements = {}
                for _, kind in ipairs({'towers', 'speakers', 'jammers', 'scanners', 'earpieces', 'mobileRepeaters'}) do
                    placements[kind] = {revision = 0}
                end
                return {schemaVersion = 1, placements = placements}
            end
            AwaitRadioPlacements = function() return true end
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
            warnLog = function(code) recordLog(formatStructuredLogMessage(code)) end
        """)
        self.lua.execute(BACKUP)

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
        if name == BACKUP_PATH:
            return self.cache
        if name == "config.lua":
            return self.config_file
        return self.legacy_files.get(name)

    def archive_config(self, original, bootstrap):
        self.assertEqual(original, self.config_file)
        self.archive_attempts.append(bootstrap)
        if not self.allow_cleanup:
            return False
        self.config_file = bootstrap
        return True

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
        self.assertEqual(self.logs, [])

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
        self.assertEqual(len(self.logs), 1)
        self.assertIn("[WRN-219]", self.logs[0])
        self.assertIn("Run sonoranradio migrate in the server console", self.logs[0])

    def test_optional_legacy_skin_and_explicit_flag_preserve_legacy_mode(self):
        self.responses = [(200, self.snapshot(True, 1)), (200, self.snapshot(True, 1))]
        self.assertTrue(self.start(local={"defaultSkinId": "custom-skin"}))
        self.assertEqual(self.settings.Config.defaultSkinId, "custom-skin")
        self.assertTrue(self.start(managed=False))
        self.assertIsNone(self.cache)
        self.assertEqual(self.get_modes, ["legacy", "legacy"])

    def boot_legacy_resource(self, response):
        self.legacy_files["towers.json"] = json.dumps([{
            "Id": "local-tower", "type": "radioTower", "Range": 4500,
            "PropPosition": {"x": 10, "y": 20, "z": 30},
        }])
        self.legacy_files["speakers.json"] = json.dumps([{
            "Id": "local-speaker", "type": "speakerLarge", "Label": "Local dispatch", "Range": 30,
            "PropPosition": {"x": 10, "y": 20, "z": 30},
        }])
        self.settings.saveFile = self.legacy_files.__setitem__
        self.lua.execute("""
            Config = {
                comId = 'demo', apiKey = 'PRIVATE-KEY', serverId = 1,
                chatterExclusions = {{componentId = 2, drawableId = 7, texture = {0}}},
                repeaterVehicleSpawncodes = {{modelHash = -45, label = 'Legacy unit', range = 150}},
            }
            local handlers = {}
            function AddEventHandler(name, fn)
                handlers[name] = handlers[name] or {}
                table.insert(handlers[name], fn)
            end
            function RegisterNetEvent(name, fn)
                if fn then AddEventHandler(name, fn) end
            end
            function TriggerEvent(name, ...)
                for _, fn in ipairs(handlers[name] or {}) do fn(...) end
            end
            function TriggerClientEvent(name, _, value)
                if name == 'SonoranRadio::core::ReceiveEnvironment' then receivedConfig = value end
            end
            RegisterCommand = function() end
            IsDuplicityVersion = function() return true end
            GetConvar = function(_, fallback) return fallback end
            GetConvarInt = GetConvar
            SetConvar = function() end
            GetResourceState = function() return 'missing' end
            GetGameTimer = function() return 0 end
            GetResourceKvpInt = function() return 0 end
            SetResourceKvpInt = function() end
            setSonoranRadioClientRoomId = function() end
            vec3 = function(x, y, z) return {x = x, y = y, z = z} end
            SaveResourceFile = function(_, name, data) saveFile(name, data); return true end
            Citizen.CreateThreadNow = function(fn) fn() end
            Citizen.CreateThread = function() end
            CreateThread = Citizen.CreateThread
            setmetatable(exports, {__call = function() end})
            local responses = {
                ['SET-SERVER-IP'] = {roomId = 1},
                ['GET-SERVER-SUBSCRIPTION'] = {subscription = 2},
                ['GET-ZONES'] = {geoZones = {}, degradeZones = {}},
                ['SET-SERVER-SPEAKERS'] = {},
            }
            exports.sonoranradio.performApiRequest = function(_, payload, endpoint, callback)
                if endpoint == 'SET-SERVER-SPEAKERS' then sentSpeakers = payload.locations end
                callback(json.encode(assert(responses[endpoint])), true)
            end
        """)
        for path in (
            "lua/config/managed.lua", "lua/config/placements.lua", "lua/sh_main.lua", "lua/sv_main.lua",
            "lua/sv_towers.lua", "lua/sv_racks.lua", "lua/sv_cell.lua", "lua/sv_toneboard.lua",
            "lua/sv_chatter.lua", "lua/sv_jammers.lua", "lua/sv_repeaters.lua",
        ):
            self.lua.execute((ROOT / path).read_text(encoding="utf-8-sig"))

        self.responses = [response]
        self.lua.execute("TriggerEvent('onResourceStart', 'sonoranradio')")

    def assert_legacy_resource_started(self):
        self.assertTrue(self.settings.Config.init)
        self.assertTrue(self.settings.AwaitRadioPlacements())
        self.assertIsNone(self.settings.receivedConfig.forceGuestLogin)
        self.assertIsNone(self.settings.receivedConfig.apiKey)
        self.assertEqual(self.settings.Towers[1].Range, 4500)
        self.assertEqual(self.settings.sentSpeakers[1].label, "Local dispatch")
        self.assertEqual(json.loads(self.legacy_files["mobileRepeaters.json"])["vehicles"][0]["label"], "Legacy unit")
        self.assertEqual(json.loads(self.legacy_files["earpieces.json"])[0]["drawableId"], 7)
        self.assertEqual(self.get_modes, ["legacy"])
        self.assertEqual(self.requests, [("GET", "")])
        self.assertIsNone(self.cache)

    def test_resource_starts_with_legacy_lua_and_placement_files_before_migration(self):
        self.boot_legacy_resource((200, self.snapshot(False, forceGuestLogin=True)))
        self.assert_legacy_resource_started()
        self.assertIn("WRN-219", [entry.code for entry in self.settings.getSupportErrorBuffer().values()])

    def test_resource_starts_with_legacy_files_without_the_settings_endpoint(self):
        self.boot_legacy_resource((404, None))
        self.assert_legacy_resource_started()

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
        self.assertEqual(json.loads(self.cache)["settings"]["revision"], 1)
        self.assertEqual(len(self.archive_attempts), 1)
        self.lua.execute(self.config_file)
        self.assertEqual(set(self.settings.Config.keys()), {"comId", "apiKey", "serverId"})
        self.assertFalse(self.settings.CanWriteRadioPlacements())
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
        self.assertEqual(json.loads(self.cache)["settings"]["revision"], 4)

    def test_cleanup_waits_for_verified_placements_and_writable_backup(self):
        remote = self.snapshot(True, 4)
        self.responses = [(200, remote)]
        self.assertTrue(self.start(local={"chatter": False}))
        placement_snapshot = self.settings.VerifyRadioPlacementMigration
        self.lua.execute("VerifyRadioPlacementMigration = function() return nil end")
        self.responses = [(200, remote)]
        self.settings.MigrateRadioSettings()
        self.assertEqual(self.archive_attempts, [])
        self.assertIsNone(self.cache)
        self.assertTrue(self.settings.CanWriteRadioPlacements())

        self.settings.VerifyRadioPlacementMigration = placement_snapshot
        self.allow_write = False
        self.responses = [(200, remote)]
        self.settings.MigrateRadioSettings()
        self.assertEqual(self.archive_attempts, [])
        self.assertIn("[WRN-220]", self.logs[-1])
        self.assertFalse(self.settings.CanWriteRadioPlacements())

    def test_cleanup_permission_warning_allows_retry_and_preserves_host_overrides(self):
        self.api_origin = "https://staging-api.dev.sonoranradio.com"
        remote = self.snapshot(True, 4)
        self.responses = [(200, remote), (200, remote)]
        self.assertTrue(self.start(local={"chatter": False, "apiUrl": self.api_origin + "/",
                                         "radioUrl": "https://staging.dev.sonoranradio.com",
                                         "allowAutoUpdate": False}))
        original = self.config_file
        self.allow_cleanup = False
        self.settings.MigrateRadioSettings()
        self.assertEqual(self.config_file, original)
        self.assertIn("[WRN-220]", self.logs[-1])
        self.assertEqual(json.loads(self.cache)["settings"]["revision"], 4)

        self.allow_cleanup = True
        self.responses = [(200, remote)]
        self.settings.MigrateRadioSettings()
        self.assertEqual(len(self.archive_attempts), 2)
        self.assertEqual([method for method, _ in self.requests], ["GET", "GET", "GET"])
        self.lua.execute(self.config_file)
        self.assertEqual(set(self.settings.Config.keys()), {"comId", "apiKey", "serverId"})
        self.lua.execute(MANAGED)
        self.responses = [(200, remote)]
        self.assertTrue(self.settings.InitializeManagedRadioSettings())
        self.assertEqual(self.settings.Config.apiUrl, self.api_origin + "/")
        self.assertEqual(self.settings.Config.radioUrl, "https://staging.dev.sonoranradio.com")
        self.assertFalse(self.settings.Config.allowAutoUpdate)

        self.lua.execute(self.config_file)
        self.settings.Config.apiKey = "DIFFERENT-KEY"
        self.lua.execute(MANAGED)
        self.assertEqual(self.settings.Config.apiUrl, "https://api.sonoranradio.com/")

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

    def test_upgrade_combines_verified_settings_and_placements_in_one_backup(self):
        self.lua.execute((ROOT / "lua/config/placements.lua").read_text(encoding="utf-8"))
        scope = {"community": "DEMO", "roomId": 1, "origin": self.api_origin}
        placements = {"schemaVersion": 1, "placements": {
            kind: {"revision": 0} for kind in (
                "towers", "speakers", "scanners", "jammers", "earpieces", "mobileRepeaters"
            )
        }}
        placements["placements"]["earpieces"] = {"revision": 2, "entries": [
            {"componentId": 2, "drawableId": 1, "texture": [0]}
        ]}
        self.legacy_files["sonoranradio-settings.json"] = json.dumps({
            "scope": scope, "document": self.snapshot(True, 2, forceGuestLogin=True),
        })
        self.legacy_files["sonoranradio-placements.json"] = json.dumps({
            "scope": scope, "document": placements,
        })

        self.responses = [(503, None)]
        self.assertTrue(self.start(managed=True))
        self.assertTrue(self.settings.Config.forceGuestLogin)

        self.responses = [(200, self.snapshot(True, 3))]
        self.assertTrue(self.start(managed=True))
        backup = json.loads(self.cache)
        self.assertEqual(backup["scope"], scope)
        self.assertEqual(backup["settings"]["revision"], 3)
        self.assertEqual(backup["placements"], placements)

        self.settings.doRequest = lambda url, callback, *_: callback(503, None)
        self.settings.InitializeManagedRadioPlacements()
        self.assertEqual(self.settings.GetPortalRadioPlacementRevision("earpieces.json"), 2)
        self.assertEqual(json.loads(self.cache), backup)

        updated = {"revision": 3, "entries": [{"componentId": 2, "drawableId": 3, "texture": [0]}]}
        self.settings.doRequest = lambda url, callback, *_: callback(200, json.dumps(updated))
        self.assertTrue(self.settings.SavePortalRadioPlacement("earpieces.json", self.to_lua(updated["entries"])))
        saved = json.loads(self.cache)
        self.assertEqual(saved["settings"], backup["settings"])
        self.assertEqual(saved["placements"]["placements"]["earpieces"], updated)
        self.assertEqual(set(self.legacy_files), {"sonoranradio-settings.json", "sonoranradio-placements.json"})

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
        self.assertFalse(json.loads(self.cache)["settings"]["configured"])

    def test_backend_reset_allows_legacy_migration_again_without_local_cleanup(self):
        local = {"forceGuestLogin": True}
        self.responses = [(200, self.snapshot(True, 2, forceGuestLogin=False))]
        self.kvp["managed_config:https://api.sonoranradio.com:DEMO:1"] = "1"
        self.assertTrue(self.start(local=local))
        self.assertFalse(self.settings.Config.forceGuestLogin)
        old_cache = self.cache

        unconfigured = self.snapshot(False)
        self.responses = [(200, unconfigured), (200, unconfigured)]
        self.assertTrue(self.start(local=local))
        self.assertTrue(self.settings.Config.forceGuestLogin)
        self.assertIsNone(self.settings.GetManagedRadioPlacementScope())
        self.assertIn("[WRN-219]", self.logs[-1])
        self.assertEqual(self.get_modes, ["managed", "managed", "legacy"])
        self.assertEqual(self.cache, old_cache)

        self.responses = [(503, None)]
        self.assertTrue(self.start(local=local))
        self.assertTrue(self.settings.Config.forceGuestLogin)
        self.assertEqual(self.get_modes[-1], "legacy")

        remigrated = self.snapshot(True, 1, forceGuestLogin=True)
        self.responses = [(200, unconfigured), (200, remigrated), (200, remigrated)]
        self.settings.MigrateRadioSettings()
        self.assertEqual([method for method, _ in self.requests[-3:]], ["GET", "POST", "GET"])
        self.assertTrue(json.loads(self.requests[-2][1])["settings"]["forceGuestLogin"])
        self.assertEqual(json.loads(self.cache)["settings"]["revision"], 1)
        self.responses = [(200, remigrated)]
        self.assertTrue(self.start(local=local))
        self.assertEqual(self.get_modes[-1], "managed")

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
        malformed_cache["settings"] = valid
        self.cache = json.dumps(malformed_cache)
        self.responses = [(503, None)]
        self.assertFalse(self.start(managed=True))

    def test_invalid_nested_lua_callback_is_not_replaced_by_portal_source(self):
        snapshot = self.snapshot(True, 1)
        snapshot["settings"]["notifications"]["type"] = "custom"
        self.responses = [(200, snapshot)]
        self.assertTrue(self.start(managed=True))
        self.assertEqual(self.settings.Config.notifications.type, "auto")
        self.assertEqual(json.loads(self.cache)["settings"]["settings"]["notifications"]["type"], "custom")


if __name__ == "__main__":
    unittest.main()
