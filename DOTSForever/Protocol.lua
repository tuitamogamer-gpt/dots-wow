local _, addon = ...
addon.Protocol = {}
local P = addon.Protocol

P.MAX_PROMPT = 2000
P.MAX_REQUEST = 14000
P.MAX_REPLY = 6000

function P.Trim(value)
    return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

function P.ValidID(value)
    return type(value) == "string" and #value > 0 and #value <= 80
        and value:match("^[A-Za-z0-9%-]+$") ~= nil
end

function P.Plain(value)
    return (value:gsub("\r\n", "\n"):gsub("\r", "\n"):gsub("[%z\1-\8\11\12\14-\31\127]", ""))
end

-- A byte limit must not split a multibyte character in localized game text.
function P.TruncateUTF8(value, limit)
    local last = math.min(#value, limit)
    while last > 0 do
        local nextByte = value:byte(last + 1)
        if not nextByte or nextByte < 128 or nextByte > 191 then break end
        last = last - 1
    end
    return value:sub(1, last)
end

-- Escape WoW's color, texture and hyperlink syntax when rendering untrusted text.
function P.Display(value)
    return (P.Plain(value):gsub("|", "||"))
end

function P.BuildRequest(id, prompt, context)
    if not P.ValidID(id) then return nil, "Neispravan ID poruke." end
    prompt = P.Trim(P.Plain(prompt or ""))
    if prompt == "" then return nil, "Prvo napisi pitanje za svog agenta." end
    if #prompt > P.MAX_PROMPT then return nil, "Pitanje je predugo (najvise 2000 UTF-8 bajtova)." end
    local lines = {
        "DOTS_REQUEST:" .. id,
        "Poruka za mog DOTS agenta iz World of Warcraft: Forever.",
        "",
        "Moje pitanje:",
        prompt,
    }
    if context and #context > 0 then
        lines[#lines + 1] = ""
        lines[#lines + 1] = "Kontekst iz igre (snimljen pri pripremi poruke):"
        for _, line in ipairs(context) do lines[#lines + 1] = line end
    end
    lines[#lines + 1] = ""
    lines[#lines + 1] = "Odgovori na hrvatskom, sazetim obicnim tekstom, do 6000 UTF-8 bajtova."
    lines[#lines + 1] = "Ne izvrsavaj radnje u igri. Ako nisi siguran u Forever mehaniku, reci to."
    lines[#lines + 1] = "Prvi redak odgovora neka bude tocno DOTS_REPLY:" .. id
    lines[#lines + 1] = "Nakon toga, u novom retku, napisi odgovor bez Markdown ograde."
    local result = table.concat(lines, "\n")
    if #result > P.MAX_REQUEST then return nil, "Poruka s kontekstom je preduga." end
    return result, prompt
end

function P.ParseReply(value, expectedID)
    if type(value) ~= "string" or #value > P.MAX_REPLY + 256 then
        return nil, "Odgovor je predug (najvise 6000 UTF-8 bajtova teksta)."
    end
    value = P.Trim(value:gsub("\r\n", "\n"):gsub("\r", "\n"))
    local unfenced = value:match("^```[^\n]*\n(.-)\n```$")
    if unfenced then value = P.Trim(unfenced) end
    local id, body = value:match("^DOTS_REPLY:([A-Za-z0-9%-]+)\n(.*)$")
    if not P.ValidID(id) then
        return nil, "Nedostaje DOTS_REPLY zaglavlje. Pripremi odgovor na pomocnoj stranici."
    end
    if not expectedID or id ~= expectedID then
        return nil, "Ovaj odgovor pripada drugom pitanju. Kopiraj odgovor za aktivnu poruku."
    end
    body = P.Trim(P.Plain(body))
    if body == "" then return nil, "Odgovor je prazan." end
    if #body > P.MAX_REPLY then return nil, "Odgovor je predug (najvise 6000 UTF-8 bajtova)." end
    return body
end
