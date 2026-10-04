"""Cross-language integration: actual addon export → helper → addon import."""
import json
from pathlib import Path
import subprocess
import unittest

from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]


class RoundtripTests(unittest.TestCase):
    def test_real_lua_request_through_js_helper_and_back(self):
        lua = LuaRuntime(unpack_returned_tuples=True)
        addon = lua.table()
        # loadfile produces an addon chunk; WoW supplies these two arguments.
        load_chunk = lua.eval("function(path) return assert(loadfile(path)) end")
        load_chunk(str(ROOT / "DOTSForever/Protocol.lua"))("DOTSForever", addon)
        request, prompt = addon.Protocol.BuildRequest(
            "1780000000-100-1", "Kako prijeći u sljedeću zonu? 🧭", lua.table_from(["Klasa: Mage"])
        )
        self.assertIn(prompt, request)
        script = """
const fs = require('node:fs');
const P = require('./companion/protocol.js');
const data = JSON.parse(fs.readFileSync(0, 'utf8'));
const request = P.parseRequest(data.request);
process.stdout.write(JSON.stringify(P.normalizeReply(data.reply, request.id)));
"""
        raw_reply = "Provjeri kartu i razinu zone. 🧭\n|cffff0000Ovo ostaje tekst.|r"
        process = subprocess.run(
            ["node", "-e", script], cwd=ROOT, check=True, capture_output=True, text=True,
            input=json.dumps({"request": request, "reply": raw_reply}),
        )
        prepared = json.loads(process.stdout)
        reply = addon.Protocol.ParseReply(prepared["text"], "1780000000-100-1")
        self.assertEqual(reply, raw_reply)
        self.assertIn("||cffff0000", addon.Protocol.Display(reply))


if __name__ == "__main__":
    unittest.main()
