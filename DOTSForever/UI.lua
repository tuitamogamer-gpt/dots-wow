local _, addon = ...
local P = addon.Protocol
local backdropTemplate = BackdropTemplateMixin and "BackdropTemplate" or nil
local colors = { gold = { .89, .72, .40 }, teal = { .49, .86, .81 }, muted = { .61, .67, .72 } }

local function panel(parent, name)
    local frame = CreateFrame("Frame", name, parent, backdropTemplate)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    frame:SetBackdropColor(.035, .055, .075, .98)
    frame:SetBackdropBorderColor(.32, .39, .43, 1)
    return frame
end

local function label(parent, text, size, color)
    local font = parent:CreateFontString(nil, "OVERLAY", size or "GameFontHighlight")
    font:SetText(text)
    font:SetJustifyH("LEFT")
    if color then font:SetTextColor(unpack(color)) end
    return font
end

local function button(parent, text, width, callback)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width, 27)
    b:SetText(text)
    b:SetScript("OnClick", callback)
    return b
end

local function editor(parent, name, width, height, limit)
    local box = panel(parent)
    box:SetSize(width, height)
    box:SetBackdropColor(.018, .028, .043, 1)
    local scroll = CreateFrame("ScrollFrame", name .. "Scroll", box, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 10, -10)
    scroll:SetPoint("BOTTOMRIGHT", -30, 10)
    local edit = CreateFrame("EditBox", name, scroll)
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    edit:SetFontObject(ChatFontNormal)
    edit:SetWidth(width - 43)
    edit:SetHeight(height - 20)
    edit:SetMaxLetters(limit)
    edit:SetTextInsets(1, 1, 1, 1)
    edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    edit:SetScript("OnCursorChanged", function(self, x, y, w, h)
        -- Keep the caret visible when typing or pasting multi-line text.
        local offset = scroll:GetVerticalScroll()
        local cursor = -y
        if cursor < offset then scroll:SetVerticalScroll(math.max(0, cursor))
        elseif cursor + h > offset + scroll:GetHeight() then
            scroll:SetVerticalScroll(math.max(0, cursor + h - scroll:GetHeight()))
        end
    end)
    scroll:SetScrollChild(edit)
    box:SetScript("OnMouseDown", function() edit:SetFocus() end)
    box:EnableMouse(true)
    return box, edit, scroll
end

function addon:Refresh()
    if not self.window then return end
    local pending = self.db.pending
    self.status:SetText(pending and "RUCNI PRIJENOS  /  Ceka se odgovor" or "RUCNI PRIJENOS  /  Spreman za pitanje")
    self.prepareButton:SetText(pending and "Kopiraj poruku" or "Pripremi poruku")
    self.history:Clear()
    if #self.db.history == 0 then
        self.history:AddMessage("Tvoj agent, na korak od Azerotha.", .89, .72, .40)
        self.history:AddMessage(" ")
        self.history:AddMessage("Napisi pitanje, kopiraj poruku u svog dota i vrati odgovor ovdje.", .78, .83, .87)
        self.history:AddMessage("Za jednostavniji prijenos otvori companion/index.html iz preuzetog paketa.", .61, .67, .72)
    else
        for _, entry in ipairs(self.db.history) do
            local heading, rgb = "OBAVIJEST", colors.muted
            if entry.role == "user" then heading, rgb = "TI", colors.gold end
            if entry.role == "agent" then heading, rgb = "DOTS  /  Uvezeni odgovor", colors.teal end
            self.history:AddMessage(heading, unpack(rgb))
            -- Separate paragraphs also avoids large individual message records.
            for line in (P.Display(entry.text) .. "\n"):gmatch("(.-)\n") do
                self.history:AddMessage(line == "" and " " or line, .87, .89, .91)
            end
            self.history:AddMessage(" ")
        end
    end
    self.history:ScrollToBottom()
end

function addon:CreateUI()
    if self.window then return end
    local f = panel(UIParent, "DOTSForeverWindow")
    self.window = f
    f:SetSize(590, 640)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relativePoint, x, y = self:GetPoint()
        addon.db.position = { point = point, relativePoint = relativePoint, x = x, y = y }
    end)
    local pos = self.db.position
    local anchors = { TOPLEFT = true, TOP = true, TOPRIGHT = true, LEFT = true, CENTER = true,
        RIGHT = true, BOTTOMLEFT = true, BOTTOM = true, BOTTOMRIGHT = true }
    if type(pos) == "table" and anchors[pos.point] and anchors[pos.relativePoint]
        and type(pos.x) == "number" and type(pos.y) == "number" then
        f:ClearAllPoints()
        f:SetPoint(pos.point, UIParent, pos.relativePoint, pos.x, pos.y)
    end
    local title = label(f, "DOTS  /  FOREVER", "GameFontNormalLarge", colors.gold)
    title:SetPoint("TOPLEFT", 24, -22)
    self.status = label(f, "", "GameFontHighlightSmall", colors.teal)
    self.status:SetPoint("TOPLEFT", 24, -49)
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -7, -7)
    close:SetScript("OnClick", function() f:Hide() end)
    table.insert(UISpecialFrames, "DOTSForeverWindow")

    local historyPanel = panel(f)
    historyPanel:SetPoint("TOPLEFT", 20, -77)
    historyPanel:SetSize(550, 278)
    self.history = CreateFrame("ScrollingMessageFrame", nil, historyPanel)
    self.history:SetPoint("TOPLEFT", 13, -12)
    self.history:SetPoint("BOTTOMRIGHT", -13, 12)
    self.history:SetFontObject(ChatFontNormal)
    self.history:SetJustifyH("LEFT")
    self.history:SetFading(false)
    self.history:SetMaxLines(1200)
    self.history:EnableMouseWheel(true)
    self.history:SetScript("OnMouseWheel", function(self, delta)
        if delta > 0 then self:ScrollUp() else self:ScrollDown() end
    end)

    local promptLabel = label(f, "Sto zelis pitati svog agenta?", nil, colors.gold)
    promptLabel:SetPoint("TOPLEFT", 24, -370)
    local inputPanel, input = editor(f, "DOTSForeverPrompt", 550, 103, P.MAX_PROMPT)
    inputPanel:SetPoint("TOPLEFT", 20, -394)
    self.input = input
    local context = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
    context:SetSize(26, 26)
    context:SetPoint("TOPLEFT", 20, -503)
    context:SetChecked(self.db.includeContext)
    context:SetScript("OnClick", function(self) addon.db.includeContext = self:GetChecked() and true or false end)
    local contextLabel = label(f, "Dodaj klasu, razinu i zonu (izvan borbe)", "GameFontHighlightSmall", colors.muted)
    contextLabel:SetPoint("LEFT", context, "RIGHT", 3, 0)
    self.error = label(f, "", "GameFontHighlightSmall")
    self.error:SetTextColor(1, .48, .40)
    self.error:SetPoint("TOPLEFT", 24, -532)
    self.error:SetWidth(540)
    self.error:SetHeight(26)

    self.prepareButton = button(f, "Pripremi poruku", 178, function()
        self.error:SetText("")
        if self.db.pending then self:ShowTransfer("export"); return end
        local ok, err = self:Prepare(input:GetText())
        if ok then input:SetText(""); input:ClearFocus() else self.error:SetText(err) end
    end)
    self.prepareButton:SetPoint("BOTTOMLEFT", 23, 44)
    local import = button(f, "Uvezi odgovor", 155, function() self:ShowTransfer("import") end)
    import:SetPoint("LEFT", self.prepareButton, "RIGHT", 8, 0)
    local cancel = button(f, "Otkazi pitanje", 155, function() self:Cancel() end)
    cancel:SetPoint("LEFT", import, "RIGHT", 8, 0)
    local foot = label(f, "/dots help  |  Glasovni poziv: telefon u ChatGPT razgovoru", "GameFontHighlightSmall", colors.muted)
    foot:SetPoint("BOTTOMLEFT", 24, 20)
    f:SetScript("OnHide", function()
        input:ClearFocus()
        if self.transfer then self.transfer:Hide() end
    end)
    self:Refresh()
    f:Hide()
end

function addon:CreateTransfer()
    local f = panel(self.window, "DOTSForeverTransfer")
    self.transfer = f
    f:SetSize(550, 465)
    f:SetPoint("CENTER")
    f:SetFrameLevel(self.window:GetFrameLevel() + 20)
    f:EnableMouse(true)
    f.title = label(f, "", "GameFontNormalLarge", colors.gold)
    f.title:SetPoint("TOPLEFT", 22, -22)
    f.help = label(f, "", "GameFontHighlightSmall", colors.muted)
    f.help:SetPoint("TOPLEFT", 22, -54)
    f.help:SetWidth(495)
    f.help:SetHeight(45)
    f.help:SetJustifyV("TOP")
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -6, -6)
    close:SetScript("OnClick", function() f:Hide() end)
    local box, edit, scroll = editor(f, "DOTSForeverTransferText", 510, 246, P.MAX_REQUEST)
    box:SetPoint("TOPLEFT", 20, -108)
    f.edit, f.scroll = edit, scroll
    edit:SetScript("OnEscapePressed", function() f:Hide() end)
    f.error = label(f, "", "GameFontHighlightSmall")
    f.error:SetTextColor(1, .48, .40)
    f.error:SetPoint("TOPLEFT", 22, -365)
    f.error:SetWidth(500)
    f.error:SetHeight(37)
    f.action = button(f, "", 195, function()
        if f.mode == "export" then
            edit:SetFocus()
            edit:HighlightText()
        else
            local ok, err = self:Import(edit:GetText())
            if ok then edit:SetText(""); f:Hide() else f.error:SetText(err) end
        end
    end)
    f.action:SetPoint("BOTTOMLEFT", 22, 23)
    local done = button(f, "Zatvori", 110, function() f:Hide() end)
    done:SetPoint("BOTTOMRIGHT", -22, 23)
    f:SetScript("OnHide", function() edit:ClearFocus() end)
    table.insert(UISpecialFrames, "DOTSForeverTransfer")
end

function addon:ShowTransfer(mode)
    self:Open()
    if not self.db.pending then
        self.error:SetText("Najprije napisi pitanje i klikni Pripremi poruku.")
        return
    end
    if not self.transfer then self:CreateTransfer() end
    local f = self.transfer
    f.mode = mode
    f.error:SetText("")
    self.input:ClearFocus()
    if mode == "export" then
        f.title:SetText("1. Posalji poruku svom dotu")
        f.help:SetText("Ctrl+C kopira oznacenu poruku. Zalijepi je na companion stranici ili izravno u svog dota na chatgpt.com/dots, pa posalji.")
        f.action:SetText("Oznaci sve za Ctrl+C")
        f.edit:SetMaxLetters(P.MAX_REQUEST)
        f.edit:SetText(self.db.pending.request)
    else
        f.title:SetText("2. Vrati odgovor u Azeroth")
        f.help:SetText("Zalijepi odgovor pomocu Ctrl+V, zajedno s DOTS_REPLY zaglavljem. Pomocna companion stranica moze dodati zaglavlje umjesto tebe.")
        f.action:SetText("Dodaj odgovor")
        -- Permit a little extra input so ParseReply can report oversize errors.
        f.edit:SetMaxLetters(P.MAX_REQUEST)
        f.edit:SetText("")
    end
    f:Show()
    f.edit:SetFocus()
    f.edit:SetCursorPosition(0)
    f.scroll:SetVerticalScroll(0)
    if mode == "export" then f.edit:HighlightText() end
end
