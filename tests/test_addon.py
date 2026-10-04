"""Run the shipped addon in Lua 5.1 against a small, strict WoW UI mock.

These are protocol/state/UI smoke tests, not a substitute for the Forever client.
The secret-value predicate is simulated; the native secret Lua type is unavailable
outside WoW. Unknown mocked widget methods fail instead of silently succeeding.
Run: python -m unittest discover -s tests -p 'test_addon.py' -v
Requires: pip install lupa
"""

from pathlib import Path
import unittest

from lupa.lua51 import LuaRuntime, lua_type


ROOT = Path(__file__).resolve().parents[1]
ADDON = ROOT / "DOTSForever"

WOW_MOCK = rb'''
MOCK = { frames = {}, messages = {}, calls = {}, secrets = {}, combat = false }
SlashCmdList = {}
UISpecialFrames = {}
ChatFontNormal = {}
BackdropTemplateMixin = {}
local Methods = {}

local setters = {
    "SetBackdropColor", "SetBackdropBorderColor", "SetTextColor", "SetJustifyH",
    "SetJustifyV", "SetFrameStrata", "SetClampedToScreen", "SetMovable",
    "EnableMouse", "RegisterForDrag", "SetFontObject", "SetFading", "SetMaxLines",
    "EnableMouseWheel", "SetMultiLine", "SetAutoFocus", "SetMaxLetters",
    "SetTextInsets", "HighlightText", "SetCursorPosition", "StartMoving",
    "StopMovingOrSizing", "ScrollUp", "ScrollDown", "ScrollToBottom",
    "UpdateScrollChildRect",
}
for _, name in ipairs(setters) do
    local method = name
    Methods[method] = function(self, ...) self.settings[method] = {...} end
end
function Methods:SetSize(width, height) self.width, self.height = width, height end
function Methods:SetWidth(width) self.width = width end
function Methods:SetHeight(height) self.height = height end
function Methods:GetHeight() return self.height or 200 end
function Methods:GetWidth() return self.width or 300 end
function Methods:SetPoint(point, relative, relativePoint, x, y)
    if type(relative) == "number" then
        x, y, relative, relativePoint = relative, relativePoint, self.parent, point
    end
    self.point = {point, relative or self.parent, relativePoint or point, x or 0, y or 0}
end
function Methods:GetPoint() return unpack(self.point or {"CENTER", UIParent, "CENTER", 0, 0}) end
function Methods:ClearAllPoints() self.point = nil end
function Methods:SetBackdrop(value)
    assert(self.template == "BackdropTemplate", "Modern frames require BackdropTemplate")
    self.backdrop = value
end
function Methods:SetFrameLevel(value) self.level = value end
function Methods:GetFrameLevel() return self.level or 1 end
function Methods:SetText(value)
    assert(type(value) == "string" or type(value) == "number", "Invalid SetText argument")
    self.text = tostring(value)
    if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self, false) end
end
function Methods:GetText() return self.text or "" end
function Methods:SetChecked(value) self.checked = value end
function Methods:GetChecked() return self.checked end
function Methods:Clear() self.messages = {} end
function Methods:AddMessage(value)
    assert(type(value) == "string", "Invalid AddMessage argument")
    self.messages[#self.messages + 1] = value
end
function Methods:SetScript(event, callback) self.scripts[event] = callback end
function Methods:GetScript(event) return self.scripts[event] end
function Methods:RegisterEvent(event) self.events[event] = true end
function Methods:UnregisterEvent(event) self.events[event] = nil end
function Methods:SetFocus()
    if MOCK.focused and MOCK.focused ~= self then MOCK.focused:ClearFocus() end
    self.focused = true
    MOCK.focused = self
end
function Methods:ClearFocus()
    self.focused = false
    if MOCK.focused == self then MOCK.focused = nil end
end
function Methods:Show()
    local wasShown = self.shown
    self.shown = true
    if not wasShown and self.scripts.OnShow then self.scripts.OnShow(self) end
end
function Methods:Hide()
    local wasShown = self.shown
    self.shown = false
    if wasShown and self.scripts.OnHide then self.scripts.OnHide(self) end
end
function Methods:IsShown() return self.shown end
function Methods:SetScrollChild(child) self.scrollChild = child end
function Methods:GetVerticalScroll() return self.scroll or 0 end
function Methods:SetVerticalScroll(value) self.scroll = value end
function Methods:CreateFontString(name, layer, template)
    return CreateFrame("FontString", name, self, template)
end

function CreateFrame(kind, name, parent, template)
    local frame = {
        kind = kind, name = name, parent = parent, template = template, shown = true,
        settings = {}, scripts = {}, events = {}, messages = {},
    }
    -- Unknown methods are nil and fail on invocation; absent data fields stay nil.
    frame = setmetatable(frame, {__index = Methods})
    if name then
        assert(_G[name] == nil, "Duplicate named frame: " .. name)
        _G[name] = frame
    end
    MOCK.frames[#MOCK.frames + 1] = frame
    return frame
end
UIParent = CreateFrame("Frame", "UIParent")
DEFAULT_CHAT_FRAME = { AddMessage = function(_, message)
    MOCK.messages[#MOCK.messages + 1] = message
end }
function time() return 1791129600 end
function GetTime() return 17.321 end
function InCombatLockdown() return MOCK.combat end
function issecretvalue(value) return MOCK.secrets[value] == true end
local function record(name)
    MOCK.calls[name] = (MOCK.calls[name] or 0) + 1
end
function UnitClass(unit) record("class"); assert(unit == "player"); return "Mage", "MAGE", 8 end
function UnitLevel(unit) record("level"); assert(unit == "player"); return 42 end
function GetZoneText() record("zone"); return "Elwynn Forest" end
function GetBuildInfo() record("build"); return "1.60.1", "70009", "Sep 23 2026", 16001 end
function MOCK.fire(event, ...)
    for _, frame in ipairs(MOCK.frames) do
        if frame.events[event] and frame.scripts.OnEvent then
            frame.scripts.OnEvent(frame, event, ...)
        end
    end
end
function MOCK.click(frame)
    assert(frame.scripts.OnClick, "Missing click handler")
    frame.scripts.OnClick(frame, "LeftButton")
end
'''


def to_python(value):
    if lua_type(value) == "table":
        return {to_python(key): to_python(item) for key, item in value.items()}
    return value


class AddonHarness:
    def __init__(self, saved=None, initialize=True):
        self.lua = LuaRuntime(encoding=None, unpack_returned_tuples=True)
        self.lua.execute(WOW_MOCK)
        self.globals = self.lua.globals()
        self.namespace = self.lua.table()
        if saved is not None:
            self.globals.DOTSForeverDB = self.lua.table_from(saved, recursive=True)
        for filename in ("Protocol.lua", "Core.lua", "UI.lua"):
            self.lua.execute((ADDON / filename).read_bytes(), b"DOTSForever", self.namespace)
        self.addon = self.globals.DOTSForever
        self.protocol = self.addon.Protocol
        if initialize:
            self.lua.execute(b'MOCK.fire("ADDON_LOADED", "DOTSForever")')

    def call(self, name, *args):
        return self.addon[name.encode()](self.addon, *args)

    def prepare(self, prompt="Gdje nastaviti questove?"):
        if isinstance(prompt, str):
            prompt = prompt.encode()
        return self.call("Prepare", prompt)

    def reply(self, body="Idi do Goldshirea.", request_id=None):
        if isinstance(body, str):
            body = body.encode()
        request_id = request_id or self.addon.db.pending.id
        return b"DOTS_REPLY:" + request_id + b"\n" + body

    def check(self, source):
        self.lua.execute(source.encode())


class AddonTests(unittest.TestCase):
    def setUp(self):
        self.h = AddonHarness()

    def test_runs_lua_51_and_defers_saved_variables_until_own_event(self):
        h = AddonHarness(saved={b"sequence": 6}, initialize=False)
        self.assertEqual(h.lua.eval(b"_VERSION"), b"Lua 5.1")
        self.assertIsNone(h.addon.db)
        h.check('MOCK.fire("ADDON_LOADED", "OtherAddon")')
        self.assertIsNone(h.addon.db)
        h.check('MOCK.fire("ADDON_LOADED", "DOTSForever")')
        self.assertEqual(h.addon.db.sequence, 6)
        h.check('MOCK.fire("ADDON_LOADED", "DOTSForever")')
        self.assertEqual(len(h.globals.MOCK.messages), 1)

    def test_request_and_matching_response_complete_actual_state_transition(self):
        h = self.h
        self.assertTrue(h.prepare("  Gdje dalje?\r\n  "))
        request_id = h.addon.db.pending.id
        self.assertTrue(h.addon.db.pending.request.startswith(b"DOTS_REQUEST:" + request_id + b"\n"))
        self.assertIn(b"DOTS_REPLY:" + request_id, h.addon.db.pending.request)
        self.assertEqual(h.addon.db.history[1].text, b"Gdje dalje?")
        self.assertTrue(h.call("Import", h.reply("  Prati put prema istoku.\r\n ")))
        self.assertIsNone(h.addon.db.pending)
        self.assertEqual(h.addon.db.history[2].role, b"agent")
        self.assertEqual(h.addon.db.history[2].text, b"Prati put prema istoku.")

    def test_blank_or_oversize_question_does_not_create_pending_or_history(self):
        for prompt in (b" \r\n\t ", "č" * 1001):
            success, error = self.h.prepare(prompt)
            self.assertIsNone(success)
            self.assertTrue(error)
            self.assertIsNone(self.h.addon.db.pending)
            self.assertEqual(self.h.addon.db.sequence, 0)
            self.assertEqual(len(self.h.addon.db.history), 0)

    def test_prompt_limit_counts_utf8_bytes_without_truncation(self):
        prompt = "č" * 1000
        self.assertTrue(self.h.prepare(prompt))
        self.assertEqual(self.h.addon.db.history[1].text.decode(), prompt)

    def test_active_question_cannot_be_overwritten(self):
        self.h.prepare("Prvo pitanje")
        previous = self.h.addon.db.pending.request
        success, _ = self.h.prepare("Drugo pitanje")
        self.assertIsNone(success)
        self.assertEqual(self.h.addon.db.pending.request, previous)
        self.assertEqual(len(self.h.addon.db.history), 1)

    def test_cancelled_stale_and_duplicate_responses_are_rejected(self):
        h = self.h
        h.prepare("Prvo")
        old_reply = h.reply("Stari odgovor")
        old_id = h.addon.db.pending.id
        h.call("Cancel")
        self.assertIsNone(h.addon.db.pending)
        h.prepare("Drugo")
        new_id = h.addon.db.pending.id
        self.assertNotEqual(old_id, new_id)  # Same clock/tick, distinct sequence.
        count = len(h.addon.db.history)
        success, _ = h.call("Import", old_reply)
        self.assertIsNone(success)
        self.assertEqual(len(h.addon.db.history), count)
        self.assertEqual(h.addon.db.pending.id, new_id)
        correct = h.reply("Novi odgovor")
        self.assertTrue(h.call("Import", correct))
        success, _ = h.call("Import", correct)
        self.assertIsNone(success)
        self.assertEqual(len(h.addon.db.history), count + 1)

    def test_malformed_or_empty_response_keeps_pending_question(self):
        h = self.h
        h.prepare()
        request_id = h.addon.db.pending.id
        for raw in (b"Samo odgovor", b"DOTS_REPLY:wrong\nOdgovor", b"DOTS_REPLY:" + request_id + b"\n\t "):
            success, _ = h.call("Import", raw)
            self.assertIsNone(success)
            self.assertEqual(h.addon.db.pending.id, request_id)
            self.assertEqual(len(h.addon.db.history), 1)

    def test_fenced_crlf_response_is_accepted(self):
        h = self.h
        h.prepare()
        raw = b" \r\n```text\r\n" + h.reply("Prvi redak.\nDrugi redak.").replace(b"\n", b"\r\n") + b"\r\n```\r\n "
        self.assertTrue(h.call("Import", raw))
        self.assertEqual(h.addon.db.history[2].text, b"Prvi redak.\nDrugi redak.")

    def test_reply_limit_counts_utf8_bytes_without_truncation(self):
        h = self.h
        h.prepare()
        success, _ = h.call("Import", h.reply("č" * 3001))
        self.assertIsNone(success)
        self.assertIsNotNone(h.addon.db.pending)
        self.assertTrue(h.call("Import", h.reply("č" * 3000)))
        self.assertEqual(h.addon.db.history[2].text.decode(), "č" * 3000)

    def test_control_characters_are_removed_but_code_and_wow_markup_stay_text(self):
        h = self.h
        h.prepare()
        body = b'|cffff0000Red|r |Tpath:64|t |Hitem:1|hItem|h\n_G.PWNED = true\x00\x01\x7f'
        self.assertTrue(h.call("Import", h.reply(body)))
        self.assertIsNone(h.globals.PWNED)
        self.assertEqual(h.addon.db.history[2].text, body[:-3])
        rendered = list(h.addon.history.messages.values())
        self.assertIn(b'||cffff0000Red||r ||Tpath:64||t ||Hitem:1||hItem||h', rendered)
        self.assertIn(b'_G.PWNED = true', rendered)

    def test_context_is_opt_in_and_does_not_read_game_apis_by_default(self):
        h = self.h
        h.prepare()
        self.assertEqual(len(h.globals.MOCK.calls), 0)
        self.assertNotIn(b"Kontekst iz igre", h.addon.db.pending.request)

    def test_opted_in_context_contains_only_available_permitted_fields(self):
        h = self.h
        h.addon.db.includeContext = True
        h.prepare()
        request = h.addon.db.pending.request
        for text in (b"Klasa: Mage", b"Razina: 42", b"Zona: Elwynn Forest", b"Verzija klijenta: 1.60.1"):
            self.assertIn(text, request)
        self.assertEqual(set(h.globals.MOCK.calls.keys()), {b"class", b"level", b"zone", b"build"})

    def test_context_does_not_read_any_game_fields_in_combat(self):
        h = self.h
        h.addon.db.includeContext = True
        h.globals.MOCK.combat = True
        h.prepare()
        self.assertEqual(len(h.globals.MOCK.calls), 0)
        self.assertIn(b"lik je u borbi", h.addon.db.pending.request)

    def test_secret_values_and_missing_or_failing_apis_are_omitted(self):
        h = self.h
        h.check('''
            DOTSForever.db.includeContext = true
            MOCK.secrets["Mage"] = true
            MOCK.secrets[42] = true
            local plain = DOTSForever.Protocol.Plain
            DOTSForever.Protocol.Plain = function(value)
                assert(not issecretvalue(value), "Secret reached text processing")
                return plain(value)
            end
            local originalTostring = tostring
            tostring = function(value)
                assert(not issecretvalue(value), "Secret reached tostring")
                return originalTostring(value)
            end
            GetZoneText = function() error("API unavailable in this state") end
            GetBuildInfo = nil
        ''')
        self.assertTrue(h.prepare())
        self.assertNotIn(b"Kontekst iz igre", h.addon.db.pending.request)

    def test_context_byte_truncation_preserves_multibyte_character_boundaries(self):
        h = self.h
        h.addon.db.includeContext = True
        h.globals.MOCK.zone = ("a" * 159 + "č" + "zona").encode()
        h.check('GetZoneText = function() return MOCK.zone end')
        self.assertTrue(h.prepare())
        request = h.addon.db.pending.request.decode("utf-8")
        self.assertIn("Zona: " + "a" * 159 + "\n", request)
        for text, limit, expected in (("č", 1, ""), ("č", 2, "č"), ("a😀b", 3, "a"), ("a😀b", 5, "a😀")):
            self.assertEqual(h.protocol.TruncateUTF8(text.encode(), limit).decode(), expected)

    def test_pending_request_and_sequence_survive_saved_variables_reload(self):
        h = self.h
        h.prepare("Pitanje prije reloada")
        request_id = h.addon.db.pending.id
        request = h.addon.db.pending.request
        reloaded = AddonHarness(saved=to_python(h.addon.db))
        self.assertEqual(reloaded.addon.db.pending.id, request_id)
        self.assertEqual(reloaded.addon.db.pending.request, request)
        self.assertTrue(reloaded.call("Import", reloaded.reply("Odgovor nakon reloada")))
        self.assertEqual(len(reloaded.addon.db.history), 2)
        self.assertTrue(reloaded.prepare("Sljedece pitanje"))
        self.assertNotEqual(reloaded.addon.db.pending.id, request_id)

    def test_corrupt_saved_records_are_discarded_and_history_is_bounded(self):
        saved = {
            b"sequence": -5,
            b"includeContext": b"yes",
            b"pending": {b"id": b"real-id", b"request": b"DOTS_REQUEST:other-id\nWrong"},
            b"history": {1: {b"role": b"invalid", b"text": b"bad"}, 2: {b"role": b"user", b"text": b"ok\x00"}},
        }
        h = AddonHarness(saved=saved)
        self.assertEqual(h.addon.db.sequence, 0)
        self.assertFalse(h.addon.db.includeContext)
        self.assertIsNone(h.addon.db.pending)
        self.assertEqual(len(h.addon.db.history), 1)
        self.assertEqual(h.addon.db.history[1].text, b"ok")
        for i in range(40):
            h.call("AddHistory", b"user", str(i).encode())
        self.assertEqual(len(h.addon.db.history), 30)
        self.assertEqual(h.addon.db.history[1].text, b"10")

    def test_mocked_ui_click_flow_can_export_import_and_release_focus(self):
        h = self.h
        h.check('''
            SlashCmdList.DOTSFOREVER("")
            assert(DOTSForever.window:IsShown())
            assert(#UISpecialFrames == 1)
            DOTSForever.input:SetText("Pitanje kroz UI")
            MOCK.click(DOTSForever.prepareButton)
            assert(DOTSForever.input:GetText() == "")
            assert(DOTSForever.transfer:IsShown())
            assert(DOTSForever.transfer.mode == "export")
            assert(DOTSForever.transfer.edit:GetText() == DOTSForever.db.pending.request)
            assert(DOTSForever.transfer.edit.settings.HighlightText)
            assert(#UISpecialFrames == 2)
            SlashCmdList.DOTSFOREVER("import")
            assert(DOTSForever.transfer.mode == "import")
            assert(DOTSForever.transfer.edit:GetText() == "")
            DOTSForever.transfer.edit:SetText("DOTS_REPLY:" .. DOTSForever.db.pending.id .. "\\nOdgovor kroz UI")
            MOCK.click(DOTSForever.transfer.action)
            assert(DOTSForever.db.pending == nil)
            assert(not DOTSForever.transfer:IsShown())
            assert(MOCK.focused == nil)
            assert(DOTSForever.db.history[2].text == "Odgovor kroz UI")
            DOTSForever:Toggle()
            assert(not DOTSForever.window:IsShown())
        ''')

    def test_ui_rejects_bad_import_without_hiding_or_clearing_the_question(self):
        h = self.h
        h.prepare()
        h.check('''
            DOTSForever:ShowTransfer("import")
            DOTSForever.transfer.edit:SetText("Odgovor bez zaglavlja")
            MOCK.click(DOTSForever.transfer.action)
            assert(DOTSForever.db.pending ~= nil)
            assert(DOTSForever.transfer:IsShown())
            assert(DOTSForever.transfer.error:GetText() ~= "")
            assert(DOTSForever.transfer.edit:GetText() == "Odgovor bez zaglavlja")
        ''')

    def test_slash_commands_clear_reset_and_report_client_version(self):
        h = self.h
        h.prepare()
        h.check('''
            SlashCmdList.DOTSFOREVER("version")
            assert(MOCK.messages[#MOCK.messages]:find("Interface 16001", 1, true))
            SlashCmdList.DOTSFOREVER("reset")
            assert(DOTSForever.db.position == nil)
            assert(DOTSForever.window:GetPoint() == "CENTER")
            SlashCmdList.DOTSFOREVER("clear")
            assert(#DOTSForever.db.history == 0)
            assert(DOTSForever.db.pending == nil)
            assert(not DOTSForever.transfer:IsShown())
            SlashCmdList.DOTSFOREVER("import")
            assert(DOTSForever.error:GetText() ~= "")
        ''')

    def test_manifest_and_binding_load_actual_files_and_forever_interface(self):
        toc = (ADDON / "DOTSForever.toc").read_text()
        self.assertIn("## Interface: 16001", toc)
        self.assertIn("## SavedVariablesPerCharacter: DOTSForeverDB", toc)
        loaded = [line.strip() for line in toc.splitlines() if line.strip() and not line.startswith("#")]
        self.assertEqual(loaded, ["Protocol.lua", "Core.lua", "UI.lua", "Bindings.xml"])
        for filename in loaded:
            self.assertTrue((ADDON / filename).is_file())
        binding = (ADDON / "Bindings.xml").read_text()
        self.assertIn('name="DOTSFOREVER_TOGGLE"', binding)
        self.assertIn("DOTSForever:Toggle()", binding)


if __name__ == "__main__":
    unittest.main()
