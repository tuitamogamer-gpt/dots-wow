(function () {
  "use strict";
  var P = window.DOTSProtocol;
  var byId = function (id) { return document.getElementById(id); };
  var request = byId("request");
  var reply = byId("reply");
  var output = byId("import-text");
  var copyReply = byId("copy-reply");
  var dotURL = byId("dot-url");
  var openDot = byId("open-dot");
  var storageKey = "dots-forever-dot-url";
  var requestRevision = 0;
  var replyRevision = 0;

  function status(id, message, isError) {
    var element = byId(id);
    element.textContent = message;
    element.classList.toggle("error", Boolean(isError));
  }

  function clearOutput() {
    output.value = "";
    copyReply.disabled = true;
  }

  function updateRequest() {
    requestRevision += 1;
    replyRevision += 1;
    clearOutput();
    status("request-status", "");
    status("reply-status", "");
    var count = P.byteLength(request.value.replace(/\r\n?/g, "\n").trim());
    byId("request-count").textContent = count.toLocaleString("hr-HR") + " / 14.000 bajtova";
    byId("request-count").classList.toggle("over-limit", count > P.REQUEST_LIMIT);
    try {
      var parsed = P.parseRequest(request.value);
      byId("request-id").textContent = "Zahtjev spreman · " + parsed.id;
      byId("request-id").classList.add("valid");
    } catch (_) {
      byId("request-id").textContent = request.value.trim() ? "Zahtjev još nije valjan. Provjeri cijeli kopirani tekst." : "Čeka se zahtjev iz igre.";
      byId("request-id").classList.remove("valid");
    }
  }

  async function copyText(text, source, statusId, success, isCurrent) {
    try {
      if (!navigator.clipboard || typeof navigator.clipboard.writeText !== "function") throw new Error("Clipboard unavailable");
      await navigator.clipboard.writeText(text);
      if (isCurrent()) status(statusId, success);
      return;
    } catch (_) {
      if (!isCurrent()) return;
      source.focus();
      source.select();
      source.setSelectionRange(0, source.value.length);
      status(statusId, "Preglednik nije omogućio automatsko kopiranje. Tekst je označen: pritisni Ctrl+C (na Macu ⌘C), ili odaberi Kopiraj u izborniku.");
    }
  }

  request.addEventListener("input", updateRequest);
  reply.addEventListener("input", function () {
    replyRevision += 1;
    clearOutput();
    status("reply-status", "");
  });

  byId("copy-request").addEventListener("click", async function () {
    try {
      var parsed = P.parseRequest(request.value);
      var revision = requestRevision;
      await copyText(parsed.text, request, "request-status", "Pitanje je kopirano. Otvori svog dota, zalijepi tekst i pošalji ga.", function () { return revision === requestRevision; });
    } catch (error) {
      status("request-status", error.message, true);
      request.focus();
    }
  });

  function prepareReply() {
    clearOutput();
    try {
      var parsed = P.parseRequest(request.value);
      var prepared = P.normalizeReply(reply.value, parsed.id);
      output.value = prepared.text;
      copyReply.disabled = false;
      status("reply-status", "Odgovor je spreman za zahtjev " + parsed.id + ". " + P.byteLength(prepared.body).toLocaleString("hr-HR") + " / 6.000 bajtova.");
      return prepared;
    } catch (error) {
      status("reply-status", error.message, true);
      return null;
    }
  }

  byId("prepare-reply").addEventListener("click", prepareReply);
  copyReply.addEventListener("click", async function () {
    var prepared = prepareReply();
    if (!prepared) return;
    var revision = replyRevision;
    await copyText(prepared.text, output, "reply-status", "Odgovor je kopiran. U igri otvori /dots i zalijepi ga u polje za odgovor.", function () { return revision === replyRevision; });
  });

  try {
    var savedURL = window.localStorage.getItem(storageKey);
    if (savedURL) {
      var validSavedURL = P.validateDotURL(savedURL);
      dotURL.value = validSavedURL;
      openDot.href = validSavedURL;
    }
  } catch (_) {
    // Private browsing and local-file policies can disable storage. The helper still works.
  }

  byId("save-url").addEventListener("click", function () {
    var validURL;
    try { validURL = P.validateDotURL(dotURL.value); }
    catch (error) { status("url-status", error.message, true); return; }
    dotURL.value = validURL;
    openDot.href = validURL;
    try {
      window.localStorage.setItem(storageKey, validURL);
      status("url-status", "Poveznica je spremljena. Gumb sada otvara tvog dota.");
    } catch (_) {
      status("url-status", "Poveznica vrijedi za ovaj otvoreni prozor. Preglednik nije omogućio trajno spremanje.");
    }
  });

  updateRequest();
})();
