(function (root, factory) {
  "use strict";
  var protocol = factory();
  if (typeof module === "object" && module.exports) module.exports = protocol;
  else root.DOTSProtocol = protocol;
})(typeof globalThis !== "undefined" ? globalThis : this, function () {
  "use strict";

  var REQUEST_LIMIT = 14000;
  var REPLY_LIMIT = 6000;
  var DEFAULT_URL = "https://chatgpt.com/dots";
  var ID_PATTERN = /^[A-Za-z0-9-]{1,80}$/;

  function byteLength(text) {
    return new TextEncoder().encode(text).length;
  }

  function cleanText(text) {
    if (typeof text !== "string") throw new Error("Zalijepi tekst poruke.");
    return text.replace(/\r\n?/g, "\n").trim();
  }

  function parseRequest(text) {
    var normalized = cleanText(text);
    if (byteLength(normalized) > REQUEST_LIMIT) {
      throw new Error("Zahtjev je predug. Dopušteno je najviše 14.000 UTF-8 bajtova.");
    }
    var lineEnd = normalized.indexOf("\n");
    var header = lineEnd < 0 ? normalized : normalized.slice(0, lineEnd);
    if (header.indexOf("DOTS_REQUEST:") !== 0) {
      throw new Error("Zalijepi cijeli zahtjev iz addona, počevši s DOTS_REQUEST:.");
    }
    var id = header.slice("DOTS_REQUEST:".length);
    if (!ID_PATTERN.test(id)) {
      throw new Error("ID zahtjeva nije valjan. Ponovno kopiraj cijeli zahtjev iz addona.");
    }
    var body = lineEnd < 0 ? "" : normalized.slice(lineEnd + 1).trim();
    if (!body) throw new Error("Zahtjev nema pitanje. Napravi novi zahtjev u addonu.");
    return { id: id, body: body, text: normalized };
  }

  function unwrapReplyFence(text) {
    // Only unwrap one complete fenced reply. Other Markdown stays plain text.
    var match = text.match(/^```[^\n]*\n(DOTS_REPLY:[\s\S]*?)\n```$/);
    return match ? match[1].trim() : text;
  }

  function normalizeReply(text, requestId) {
    if (typeof requestId !== "string" || !ID_PATTERN.test(requestId)) {
      throw new Error("Najprije zalijepi valjan zahtjev iz addona.");
    }
    var normalized = unwrapReplyFence(cleanText(text));
    if (!normalized) throw new Error("Zalijepi stvarni odgovor svog DOTS agenta.");
    var body = normalized;
    if (normalized.indexOf("DOTS_REQUEST:") === 0) {
      throw new Error("Ovo je zahtjev iz addona. Ovdje zalijepi odgovor agenta.");
    }
    if (normalized.indexOf("DOTS_REPLY") === 0) {
      var lineEnd = normalized.indexOf("\n");
      var header = lineEnd < 0 ? normalized : normalized.slice(0, lineEnd);
      if (header.indexOf("DOTS_REPLY:") !== 0 || !ID_PATTERN.test(header.slice(11))) {
        throw new Error("Zaglavlje odgovora nije valjano. Očekuje se DOTS_REPLY: i ID zahtjeva.");
      }
      var replyId = header.slice(11);
      if (replyId !== requestId) {
        throw new Error("Odgovor pripada drugom zahtjevu (" + replyId + "). Zalijepi odgovor za " + requestId + ".");
      }
      body = lineEnd < 0 ? "" : normalized.slice(lineEnd + 1).trim();
    }
    if (!body) throw new Error("Odgovor je prazan. Kopiraj i tekst odgovora, ne samo zaglavlje.");
    if (byteLength(body) > REPLY_LIMIT) {
      throw new Error("Odgovor je predug. Zamoli agenta za kraći odgovor: najviše 6.000 UTF-8 bajtova.");
    }
    return { id: requestId, body: body, text: "DOTS_REPLY:" + requestId + "\n" + body };
  }

  function validateDotURL(value) {
    var input = typeof value === "string" ? value.trim() : "";
    var url;
    try { url = new URL(input || DEFAULT_URL); }
    catch (_) { throw new Error("Upiši valjanu poveznicu koja počinje s https://chatgpt.com/."); }
    if (url.protocol !== "https:" || url.hostname !== "chatgpt.com" || url.port || url.username || url.password) {
      throw new Error("Dopuštene su samo HTTPS poveznice na chatgpt.com.");
    }
    return url.href;
  }

  return {
    REQUEST_LIMIT: REQUEST_LIMIT,
    REPLY_LIMIT: REPLY_LIMIT,
    DEFAULT_URL: DEFAULT_URL,
    byteLength: byteLength,
    parseRequest: parseRequest,
    normalizeReply: normalizeReply,
    validateDotURL: validateDotURL
  };
});
