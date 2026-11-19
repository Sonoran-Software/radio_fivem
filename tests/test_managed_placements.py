"""Scoped placement import, save, and backup behavior for the FiveM resource."""

import json
from pathlib import Path
import unittest

from lupa import LuaRuntime, lua_type


ROOT = Path(__file__).resolve().parents[1]
SOURCE = (ROOT / "lua/config/placements.lua").read_text(encoding="utf-8")
BACKUP = (ROOT / "lua/config/backup.lua").read_text(encoding="utf-8")
BACKUP_PATH = "lua/config/.configuration-cache.json"
KINDS = ("towers", "speakers", "jammers", "scanners", "earpieces", "mobileRepeaters")
SPEAKER = {
    "Id": "speaker-1", "type": "speakerMediumWall",
    "PropPosition": {"x": 100, "y": 200, "z": 30},
    "heading": 60, "Range": 40, "Label": "Dispatch", "group": "County",
}


def document(**collections):
    return {
        "schemaVersion": 1,
        "placements": {
            kind: {"revision": collections[kind][0], "entries": collections[kind][1]}
            if kind in collections else {"revision": 0, "entries": None}
            for kind in KINDS
        },
    }


class ManagedPlacementTests(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime()
        self.globals = self.lua.globals()
        self.scope = {"community": "DEMO", "roomId": 1, "origin": "https://api.sonoranradio.com"}
        self.files = {}
        self.requests = []
        self.responses = []
        self.logs = []
        self.globals.decodeJSON = lambda raw: self.to_lua(json.loads(raw))
        self.globals.encodeJSON = lambda value: json.dumps(self.to_python(value))
        self.globals.loadFile = self.files.get
        self.globals.saveBackup = self.save_backup
        self.globals.scope = self.to_lua(self.scope)
        self.globals.request = self.request
        self.globals.log = self.logs.append
        self.lua.execute("""
            Config = { apiKey = 'SECRET', init = true }
            GetManagedRadioPlacementScope = function() return scope end
            GetCurrentResourceName = function() return 'sonoranradio' end
            LoadResourceFile = function(_, path) return loadFile(path) end
            NormalizeRadioMobileRepeaterImport = function(raw) return raw.vehicles or {} end
            IsPlayerAceAllowed = function(src, ace) return src == 42 and ace == 'command.radioMenu' end
            print = function(value) log(value) end
            json = {
                decode = function(raw) return decodeJSON(raw) end,
                encode = function(value) return encodeJSON(value) end,
            }
            promise = {
                new = function() return { resolve = function(self, value) self.value = value end } end
            }
            Citizen = {
                Await = function(promise) return assert(promise.value) end,
                SetTimeout = function(_, callback) timeout = callback end,
            }
            PerformHttpRequest = function(...) request(...) end
            exports = { sonoranradio = {
                WriteManagedRadioConfigBackup = function(_, value) return saveBackup(value) end
            } }
        """)
        self.lua.execute(BACKUP)

    def to_lua(self, value):
        if isinstance(value, dict):
            return self.lua.table_from({key: self.to_lua(entry) for key, entry in value.items()})
        if isinstance(value, list):
            return self.lua.table_from([self.to_lua(entry) for entry in value])
        return value

    def to_python(self, value):
        if lua_type(value) != "table":
            return value
        keys = list(value.keys())
        if keys and set(keys) == set(range(1, len(keys) + 1)):
            return [self.to_python(value[index]) for index in range(1, len(keys) + 1)]
        return {key: self.to_python(entry) for key, entry in value.items()}

    def request(self, url, callback, method, body, headers, options):
        self.requests.append((method, url, json.loads(body) if body else None, headers.Authorization, options.followLocation))
        status, response = self.responses.pop(0)
        callback(status, json.dumps(response) if response is not None else None)

    def save_backup(self, value):
        self.assertNotIn("SECRET", value)
        self.files[BACKUP_PATH] = value
        return True

    def boot(self):
        self.lua.execute(SOURCE)
        self.globals.InitializeManagedRadioPlacements()

    def test_existing_files_import_only_missing_collections(self):
        original = [dict(SPEAKER, Handle=123, Spawned=False)]
        self.files["speakers.json"] = json.dumps(original)
        self.files["towers.json"] = json.dumps([])
        self.files["mobileRepeaters.json"] = json.dumps({
            "version": 1, "migratedFromConfig": False,
            "vehicles": [{"modelHash": -45, "label": "Command", "range": 150}],
        })
        vehicles = [{"modelHash": -45, "label": "Command", "range": 150}]
        empty_towers = document(towers=(1, []))
        self.responses = [(200, empty_towers), (200, document(
            speakers=(1, [SPEAKER]), towers=(1, []), mobileRepeaters=(1, vehicles),
        ))]
        self.boot()
        self.assertEqual(self.requests, [
            ("GET", "https://api.sonoranradio.com/v2/servers/DEMO/rooms/1/fivem-placements", None, "Bearer SECRET", False),
            ("POST", "https://api.sonoranradio.com/v2/servers/DEMO/rooms/1/fivem-placements/import",
             {"placements": {"speakers": [SPEAKER], "mobileRepeaters": vehicles}}, "Bearer SECRET", False),
        ])
        self.assertEqual(json.loads(self.files["speakers.json"]), original)
        self.assertEqual(self.to_python(self.globals.GetPortalRadioPlacement("speakers.json")), [SPEAKER])
        self.assertEqual(self.to_python(self.globals.GetPortalRadioPlacement("towers.json")), {})
        self.assertEqual(self.to_python(self.globals.GetPortalRadioPlacement("mobileRepeaters.json")), {
            "version": 1, "migratedFromConfig": True, "vehicles": vehicles,
        })

    def test_new_server_without_templates_can_save_a_first_placement(self):
        self.responses = [(200, document())]
        self.boot()
        self.assertEqual([item[0] for item in self.requests], ["GET"])
        self.assertTrue(self.globals.MatchesRadioPlacementRevision("speakers.json", 0))
        self.responses = [(200, {"revision": 1, "entries": [SPEAKER]})]
        self.assertTrue(self.globals.SavePortalRadioPlacement("speakers.json", self.to_lua([SPEAKER])))
        self.assertEqual(self.requests[-1][2], {"revision": 0, "entries": [SPEAKER]})
        self.assertEqual(set(self.files), {BACKUP_PATH})

    def test_cleanup_requires_a_fresh_backend_read_of_imported_placements(self):
        self.files["speakers.json"] = json.dumps([SPEAKER])
        self.lua.execute(SOURCE)
        imported = document(speakers=(1, [SPEAKER]))
        self.responses = [(200, document()), (200, imported), (503, None)]
        self.assertIsNone(self.globals.VerifyRadioPlacementMigration(self.globals.scope))
        self.assertEqual([item[0] for item in self.requests], ["GET", "POST", "GET"])
        self.assertEqual(json.loads(self.files["speakers.json"]), [SPEAKER])

        self.responses = [(200, imported)]
        verified = self.globals.VerifyRadioPlacementMigration(self.globals.scope)
        self.assertEqual(self.to_python(verified)["placements"]["speakers"]["entries"], [SPEAKER])
        self.assertEqual([item[0] for item in self.requests], ["GET", "POST", "GET", "GET"])

    def test_cleanup_leaves_unconfigured_malformed_placement_files_for_retry(self):
        self.files["speakers.json"] = "{broken"
        self.lua.execute(SOURCE)
        self.responses = [(200, document())]
        self.assertIsNone(self.globals.VerifyRadioPlacementMigration(self.globals.scope))
        self.assertEqual([item[0] for item in self.requests], ["GET"])

    def test_lua_only_legacy_placements_import_without_json_templates(self):
        earpieces = [{"componentId": 2, "drawableId": 1, "texture": [0]}]
        vehicles = [{"modelHash": -45, "label": "Command", "range": 150}]
        self.globals.Config.chatterExclusions = self.to_lua(earpieces)
        self.globals.Config.repeaterVehicleSpawncodes = self.to_lua(vehicles)
        self.lua.execute("""
            IsDuplicityVersion = function() return true end
            RegisterNetEvent = function() end
            AddEventHandler = function() end
        """)
        for path in ("lua/sh_main.lua", "lua/sv_repeaters.lua"):
            self.lua.execute((ROOT / path).read_text(encoding="utf-8-sig"))
        self.responses = [(200, document()), (200, document(
            earpieces=(1, earpieces), mobileRepeaters=(1, vehicles),
        ))]
        self.boot()
        self.assertEqual(self.requests[-1][2], {"placements": {
            "earpieces": earpieces, "mobileRepeaters": vehicles,
        }})
        self.assertEqual(set(self.files), {BACKUP_PATH})

    def test_write_conflict_leaves_original_and_success_updates_one_kind(self):
        self.responses = [(200, document(speakers=(5, [SPEAKER]), towers=(9, [])))]
        self.boot()
        original_cache = self.files[BACKUP_PATH]
        proposed = [dict(SPEAKER, Label="Updated")]
        self.responses = [(409, None), (200, {"revision": 6, "entries": proposed})]
        self.assertFalse(self.globals.SavePortalRadioPlacement("speakers.json", self.to_lua(proposed)))
        self.assertEqual(self.files[BACKUP_PATH], original_cache)
        self.assertTrue(self.globals.SavePortalRadioPlacement("speakers.json", self.to_lua(proposed)))
        self.assertEqual([item[2]["revision"] for item in self.requests if item[0] == "PATCH"], [5, 5])
        self.assertEqual(self.to_python(self.globals.GetPortalRadioPlacement("speakers.json")), proposed)
        self.assertEqual(json.loads(self.files[BACKUP_PATH])["placements"]["placements"]["towers"]["revision"], 9)

    def test_only_same_room_valid_backup_can_load_during_outage(self):
        self.responses = [(200, document(speakers=(5, [SPEAKER])))]
        self.boot()
        self.responses = [(200, document(speakers=(6, [dict(SPEAKER, Range="invalid")])))]
        self.boot()
        self.assertEqual(self.to_python(self.globals.GetPortalRadioPlacement("speakers.json")), [SPEAKER])
        self.responses = [(503, None)]
        self.assertFalse(self.globals.SavePortalRadioPlacement("speakers.json", self.to_lua([])))
        self.responses = [(200, {"revision": 6, "entries": []})]
        self.assertTrue(self.globals.SavePortalRadioPlacement("speakers.json", self.to_lua([])))
        self.responses = [(403, None)]
        self.boot()
        self.assertIsNone(self.globals.GetPortalRadioPlacement("speakers.json"))
        self.assertFalse(self.globals.SavePortalRadioPlacement("speakers.json", self.to_lua([])))
        self.globals.scope.roomId = 2
        self.responses = [(503, None)]
        self.boot()
        self.assertIsNone(self.globals.GetPortalRadioPlacement("speakers.json"))
        self.assertFalse(self.globals.SavePortalRadioPlacement("speakers.json", self.to_lua([])))

    def test_legacy_placement_edits_stay_local_and_require_the_menu_ace(self):
        self.globals.scope = None
        self.boot()
        self.assertIsNone(self.globals.SavePortalRadioPlacement("speakers.json", self.to_lua([])))
        self.assertFalse(self.globals.CanManageRadioPlacements(42))
        self.globals.MarkRadioPlacementsLoaded()
        self.assertTrue(self.globals.CanManageRadioPlacements(42))
        self.assertFalse(self.globals.CanManageRadioPlacements(43))
        self.assertEqual(self.requests, [])

    def test_stale_in_game_editor_drafts_get_resynced_to_their_sender(self):
        self.responses = [(200, document(speakers=(5, [SPEAKER]), towers=(6, []), earpieces=(7, [])))]
        self.boot()
        self.lua.execute("""
            source = 42
            handlers = {}
            sent = {}
            IsDuplicityVersion = function() return true end
            RegisterNetEvent = function(name, fn) if fn then handlers[name] = fn end end
            AddEventHandler = function(name, fn) handlers[name] = fn end
            RegisterCommand = function() end
            TriggerClientEvent = function(name, target, ...)
                sent[#sent + 1] = { name = name, target = target, args = {...} }
            end
            setmetatable(exports, {__call = function() end})
        """)
        for path in ("lua/sh_main.lua", "lua/sv_main.lua", "lua/sv_chatter.lua"):
            self.lua.execute((ROOT / path).read_text(encoding="utf-8-sig"))
        self.lua.execute("""
            MarkRadioPlacementsLoaded()
            Towers, Servers, CellRepeaters = {}, {}, {}
            Speakers = GetPortalRadioPlacement('speakers.json')
            handlers['SonoranRadio::MoveProp']({}, {}, {}, 5)
            handlers['SonoranRadio::MoveSpeaker']({}, 4)
            handlers['Chatter:saveChatterConfig']({}, 6)
            assert(#sent == 8)
            for _, event in ipairs(sent) do assert(event.target == 42) end
            assert(sent[2].name == 'RadioTower:SyncTowers' and sent[2].args[2] == 6)
            assert(sent[3].name == 'RadioRacks:SyncRacks' and sent[3].args[2] == 6)
            assert(sent[4].name == 'CellRepeater:SyncCellRepeaters' and sent[4].args[2] == 6)
            assert(sent[6].name == 'SonoranRadio:SyncSpeakers' and sent[6].args[2] == 5)
            assert(sent[6].args[1][1].Label == 'Dispatch')
            assert(sent[8].name == 'Chatter:clientChatterSync_c' and sent[8].args[2] == 7)
            assert(ApplyRadioPlacementRevision('towers', 6))
            assert(not ApplyRadioPlacementRevision('towers', 5))
            assert(RadioPlacementRevisions.towers == 6)
        """)
        self.assertEqual([item[0] for item in self.requests], ["GET"])


if __name__ == "__main__":
    unittest.main()
