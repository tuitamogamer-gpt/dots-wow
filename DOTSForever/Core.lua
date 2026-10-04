local addonName, addon = ...
_G.DOTSForever = addon
addon.name = addonName
addon.version = "0.1.0"
local P = addon.Protocol

BINDING_HEADER_DOTSFOREVER = "DOTS Forever"
BINDING_NAME_DOTSFOREVER_TOGGLE = "Otvori / zatvori DOTS agenta"

function addon:Print(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cff7ddccfDOTS|r " .. P.Display(message))
end

function addon:AddHistory(role, text)
    local history = self.db.history
    history[#history + 1] = { role = role, text = text }
    while #history > 30 do table.remove(history, 1) end
end

local function safeValue(func, ...)
    if type(func) ~= "function" then return nil end
    local ok, value = pcall(func, ...)
    if not ok or (issecretvalue and issecretvalue(value)) then return nil end
    if type(value) == "string" then return P.TruncateUTF8(P.Plain(value), 160) end
    if type(value) == "number" then return tostring(value) end
end

function addon:Context()
    if not self.db.includeContext then return nil end
    -- Forever uses the modern restricted combat API. Never inspect combat data.
    if InCombatLockdown and InCombatLockdown() then
        return { "Kontekst nije prikupljen: lik je u borbi." }
    end
    local lines = {}
    local values = {
        { "Klasa", safeValue(UnitClass, "player") },
        { "Razina", safeValue(UnitLevel, "player") },
        { "Zona", safeValue(GetZoneText) },
        { "Verzija klijenta", safeValue(GetBuildInfo) },
    }
    for _, item in ipairs(values) do
        if item[2] and item[2] ~= "" then lines[#lines + 1] = item[1] .. ": " .. item[2] end
    end
    return lines
end

function addon:Prepare(prompt)
    if self.db.pending then
        self:ShowTransfer("export")
        return nil, "Prvo uvezi odgovor ili otkazi aktivno pitanje."
    end
    local sequence = self.db.sequence + 1
    local id = string.format("%d-%d-%d", time(), math.floor(GetTime() * 1000), sequence)
    local request, cleaned = P.BuildRequest(id, prompt, self:Context())
    if not request then return nil, cleaned end
    self.db.sequence = sequence
    self.db.pending = { id = id, request = request }
    self:AddHistory("user", cleaned)
    self:Refresh()
    self:ShowTransfer("export")
    return true
end

function addon:Import(value)
    if not self.db.pending then return nil, "Nema aktivnog pitanja. Najprije pripremi poruku." end
    local body, err = P.ParseReply(value, self.db.pending.id)
    if not body then return nil, err end
    self:AddHistory("agent", body)
    self.db.pending = nil
    self:Refresh()
    return true
end

function addon:Cancel()
    if self.db.pending then
        self.db.pending = nil
        self:AddHistory("system", "Pitanje je otkazano u addonu. Rad pokrenut u ChatGPT-u time se ne zaustavlja.")
        self:Refresh()
        if self.transfer then self.transfer:Hide() end
    else
        self:Print("Nema aktivnog pitanja.")
    end
end

function addon:Toggle()
    if not self.db then return end
    if not self.window then self:CreateUI() end
    if self.window:IsShown() then self.window:Hide() else self.window:Show() end
end

function addon:Open()
    if not self.window then self:CreateUI() end
    self.window:Show()
end

function addon:Initialize()
    local db = type(DOTSForeverDB) == "table" and DOTSForeverDB or {}
    DOTSForeverDB = db
    self.db = db
    db.includeContext = db.includeContext == true
    db.sequence = type(db.sequence) == "number" and db.sequence >= 0 and db.sequence < 1000000000
        and math.floor(db.sequence) or 0
    local history = {}
    if type(db.history) == "table" then
        for _, entry in ipairs(db.history) do
            if type(entry) == "table" and type(entry.text) == "string" and #entry.text <= P.MAX_REPLY
                and (entry.role == "user" or entry.role == "agent" or entry.role == "system") then
                history[#history + 1] = { role = entry.role, text = P.Plain(entry.text) }
                if #history > 30 then table.remove(history, 1) end
            end
        end
    end
    db.history = history
    if type(db.pending) ~= "table" or not P.ValidID(db.pending.id)
        or type(db.pending.request) ~= "string" or #db.pending.request > P.MAX_REQUEST
        or db.pending.request:sub(1, #("DOTS_REQUEST:" .. (db.pending.id or "") .. "\n"))
            ~= "DOTS_REQUEST:" .. (db.pending.id or "") .. "\n" then
        db.pending = nil
    end
    self:Print("Spreman. /dots otvara agenta; /dots help prikazuje upute. Veza: rucni prijenos.")
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(self, _, loaded)
    if loaded ~= addonName then return end
    addon:Initialize()
    self:UnregisterEvent("ADDON_LOADED")
end)

SLASH_DOTSFOREVER1 = "/dots"
SLASH_DOTSFOREVER2 = "/dot"
SlashCmdList.DOTSFOREVER = function(message)
    if not addon.db then return end
    message = P.Trim(message or "")
    local command, rest = message:match("^(%S+)%s*(.*)$")
    command = command and command:lower() or ""
    if command == "help" then
        addon:Print("/dots — prozor; /dots ask pitanje — pripremi poruku; /dots import — uvezi odgovor.")
        addon:Print("/dots cancel — otkazi pitanje; /dots clear — obrisi razgovor; /dots reset — vrati polozaj; /dots version — klijent.")
        addon:Print("Kopiraj poruku u svoj dot na chatgpt.com/dots. Glasovni poziv pokreni tipkom telefona u razgovoru.")
    elseif command == "ask" then
        addon:Open()
        local ok, err = addon:Prepare(rest)
        if not ok then addon:Print(err) end
    elseif command == "import" then
        addon:Open()
        addon:ShowTransfer("import")
    elseif command == "cancel" then
        addon:Cancel()
    elseif command == "clear" then
        addon.db.history = {}
        addon.db.pending = nil
        if addon.transfer then addon.transfer:Hide() end
        addon:Refresh()
        addon:Print("Lokalni razgovor je obrisan. Razgovor u ChatGPT-u ostaje u ChatGPT-u.")
    elseif command == "reset" then
        addon:Open()
        addon.window:ClearAllPoints()
        addon.window:SetPoint("CENTER")
        addon.db.position = nil
    elseif command == "version" then
        local version, build, _, interface = GetBuildInfo()
        addon:Print("Klijent " .. tostring(version) .. " / build " .. tostring(build) .. " / Interface " .. tostring(interface))
    elseif command == "" then
        addon:Toggle()
    else
        addon:Print("Nepoznata naredba. /dots help prikazuje upute; /dots ask tvoje pitanje priprema poruku.")
    end
end
