"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const P = require("../companion/protocol.js");

test("parses a real addon request and normalizes Windows line endings", () => {
  assert.deepEqual(P.parseRequest("DOTS_REQUEST:abc-42\r\nKoji talent?\r\nVrati DOTS_REPLY:abc-42\r\n"), {
    id: "abc-42", body: "Koji talent?\nVrati DOTS_REPLY:abc-42", text: "DOTS_REQUEST:abc-42\nKoji talent?\nVrati DOTS_REPLY:abc-42"
  });
});

test("request requires exact valid header, ID and nonempty question", () => {
  for (const text of ["obično pitanje", "DOTS_REQUEST:\nPitanje", "DOTS_REQUEST:id_1\nPitanje", "DOTS_REQUEST:id:1\nPitanje", "DOTS_REQUEST:" + "a".repeat(81) + "\nPitanje", "DOTS_REQUEST:abc", "DOTS_REQUEST:abc\n   "]) {
    assert.throws(() => P.parseRequest(text));
  }
  assert.equal(P.parseRequest("DOTS_REQUEST:" + "a".repeat(80) + "\nPitanje").id.length, 80);
});

test("request limit is UTF-8 bytes of the complete request, not characters", () => {
  const header = "DOTS_REQUEST:a\n";
  const fit = header + "a".repeat(14000 - P.byteLength(header) - 4) + "🧙";
  assert.equal(P.byteLength(fit), 14000);
  assert.equal(P.parseRequest(fit).text, fit);
  assert.throws(() => P.parseRequest(fit + "a"), /predug/);
});

test("plain answer receives the request ID without evaluating or escaping text", () => {
  const body = '<script>alert("x")</script>\n|cffff0000Primjer|r\nćčšđž';
  assert.deepEqual(P.normalizeReply(body, "real-123"), { id: "real-123", body, text: "DOTS_REPLY:real-123\n" + body });
});

test("matching reply ID is retained and mismatched or malformed IDs fail closed", () => {
  assert.equal(P.normalizeReply("DOTS_REPLY:abc-42\r\nOdgovor", "abc-42").text, "DOTS_REPLY:abc-42\nOdgovor");
  for (const answer of ["DOTS_REPLY:other\nOdgovor", "DOTS_REPLY:abc_42\nOdgovor", "DOTS_REPLY abc-42\nOdgovor", "DOTS_REPLY:abc-42", "DOTS_REPLY:abc-42\n ", "DOTS_REQUEST:abc-42\nPitanje"]) {
    assert.throws(() => P.normalizeReply(answer, "abc-42"));
  }
  assert.throws(() => P.normalizeReply("Odgovor", "bad_id"));
  assert.throws(() => P.normalizeReply("  ", "abc-42"));
});

test("unwraps a complete fenced DOTS_REPLY only and checks its ID", () => {
  assert.equal(P.normalizeReply("```text\nDOTS_REPLY:abc\nOdgovor\n```", "abc").text, "DOTS_REPLY:abc\nOdgovor");
  assert.equal(P.normalizeReply("```\r\nDOTS_REPLY:abc\r\nOdgovor\r\n```", "abc").body, "Odgovor");
  assert.throws(() => P.normalizeReply("```text\nDOTS_REPLY:other\nOdgovor\n```", "abc"), /drugom/);
  assert.equal(P.normalizeReply("```lua\nprint('tekst')\n```", "abc").body, "```lua\nprint('tekst')\n```");
});

test("answer body alone has a strict 6000-byte limit, including Unicode", () => {
  const fit = "ž".repeat(2998) + "🧙";
  assert.equal(P.byteLength(fit), 6000);
  assert.equal(P.normalizeReply(fit, "abc").body, fit);
  assert.equal(P.normalizeReply("DOTS_REPLY:abc\n" + fit, "abc").body, fit);
  assert.throws(() => P.normalizeReply(fit + "a", "abc"), /predug/);
});

test("dot links allow only HTTPS on the exact ChatGPT host with no credentials", () => {
  assert.equal(P.validateDotURL(""), "https://chatgpt.com/dots");
  assert.equal(P.validateDotURL(" https://chatgpt.com/dots/real-agent "), "https://chatgpt.com/dots/real-agent");
  assert.equal(P.validateDotURL("https://chatgpt.com:443/dots"), "https://chatgpt.com/dots");
  for (const url of ["http://chatgpt.com/dots", "https://chatgpt.com.evil.test", "https://evil.test/chatgpt.com", "https://chatgpt.com@evil.test", "https://user@chatgpt.com", "https://chatgpt.com:8080/dots", "javascript:alert(1)", "file:///tmp/a", "//chatgpt.com/dots"]) {
    assert.throws(() => P.validateDotURL(url));
  }
});
