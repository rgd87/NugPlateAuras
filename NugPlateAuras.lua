local addonName, ns = ...


local NugPlateAuras = CreateFrame("Frame", "NugPlateAuras", UIParent)
NugPlateAuras:SetScript("OnEvent", function(self, event, ...)
    return self[event](self, event, ...)
end)

local isClassic = WOW_PROJECT_ID == WOW_PROJECT_CLASSIC

local db
local LibAuraTypes
local LibSpellLocks
local LibCustomGlow
local LibClassicDurations

local Masque = LibStub("Masque", true)
local MasqueGroup
NugPlateAuras:RegisterEvent("ADDON_LOADED")


local UnitAura = _G.UnitAura
local activePlateUnits = {}
local PlateGUIDtoUnit = {}

local defaults = {
    profile = {
        enableMasque = false,
        enableBuffGains = true,
        splitAuras = true,
        buffs = {
            attachPoint = "TOP",
            auraGrowth = "RIGHT",
            maxAuras = 3,
            priorityThreshold = 50,
            auraSize = 25,
            auraGap = 2,
            npOffsetX = 0,
            npOffsetY = 10,
        },
        debuffs = {
            attachPoint = "TOP",
            auraGrowth = "RIGHT",
            maxAuras = 3,
            priorityThreshold = 50,
            auraSize = 25,
            auraGap = 2,
            npOffsetX = 0,
            npOffsetY = 10,
        },
        floatingOffsetX = 0,
        floatingOffsetY = -15,
    }
}

function NugPlateAuras.ADDON_LOADED(self,event,arg1)
    if arg1 == addonName then

        NugPlateAurasDB = NugPlateAurasDB or {}
        self:DoMigrations(NugPlateAurasDB)
        self.db = LibStub("AceDB-3.0"):New("NugPlateAurasDB", defaults, "Default") -- Create a DB using defaults and using a shared default profile
        db = self.db

        self.db.RegisterCallback(self, "OnProfileChanged", "Reconfigure")
        self.db.RegisterCallback(self, "OnProfileCopied", "Reconfigure")
        self.db.RegisterCallback(self, "OnProfileReset", "Reconfigure")

        LibAuraTypes = LibStub("LibAuraTypes")
        LibSpellLocks = LibStub("LibSpellLocks")
        LibCustomGlow = LibStub("LibCustomGlow-1.0")
        if isClassic then
            LibClassicDurations = LibStub("LibClassicDurations")
            LibClassicDurations:Register(addonName)
            UnitAura = LibClassicDurations.UnitAuraWithBuffs
            LibClassicDurations.RegisterCallback(self, "UNIT_BUFF", function(event, unit)
                self:UNIT_AURA(event, unit)
            end)
        end

        if db.enableBuffGains then
            if isClassic then
                LibClassicDurations.RegisterCallback(self, "UNIT_BUFF_GAINED", function(event, unit, spellID)
                    self:UNIT_AURA_GAINED(event, unit, spellID, "BUFF")
                end)
            else
                self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
            end
        end

        -- PRIORITY_THRESHOLD = LibAuraTypes.GetDebuffTypePriority("SILENCE")

        LibSpellLocks.RegisterCallback(self, "UPDATE_INTERRUPT", function(event, guid)
            local unit = PlateGUIDtoUnit[guid]
            if unit then
                self:UNIT_AURA(event, unit)
            end
        end)

        if Masque and db.enableMasque then
            ns.MasqueGroup = Masque:Group(addonName, "NugPlateAuras")
        end

        self:RegisterEvent("NAME_PLATE_CREATED")
        self:RegisterEvent("NAME_PLATE_UNIT_ADDED")
        self:RegisterEvent("NAME_PLATE_UNIT_REMOVED")

        self:RegisterEvent("UNIT_AURA")

        SLASH_NUGPLATEAURAS1 = "/nugplateauras"
        SLASH_NUGPLATEAURAS2 = "/npa"
        SlashCmdList["NUGPLATEAURAS"] = self.SlashCmd

        NugPlateAuras:HookOptionsFrame()
    end
end
function NugPlateAuras:PLAYER_LOGOUT(event)
    RemoveDefaults(db, defaults)
end

function NugPlateAuras.NAME_PLATE_CREATED(self, event, np)
    if not np.NugPlateAurasFrame then
        self:CreateHeader(np)
    end
end

function NugPlateAuras.NAME_PLATE_UNIT_ADDED(self, event, unit)
    if UnitIsUnit(unit, "player") or UnitReaction(unit, "player") >= 5 then return end
    local np = C_NamePlate.GetNamePlateForUnit(unit)
    activePlateUnits[unit] = true
    PlateGUIDtoUnit[UnitGUID(unit)] = unit
    self:UNIT_AURA(event, unit)
    -- if not np.NugPlateAurasFrame then
    --     self:CreateHeader(np)
    -- end
end

function NugPlateAuras.NAME_PLATE_UNIT_REMOVED(self, event, unit)
    local np = C_NamePlate.GetNamePlateForUnit(unit)
    activePlateUnits[unit] = nil
    PlateGUIDtoUnit[UnitGUID(unit)] = nil
    if np.NugPlateAurasFrame then
        for _, aura in ipairs(np.NugPlateAurasFrame.auras) do
            aura:Hide()
        end
    end
end


local RepositionAuraFrames = function(hdr)
    local size = db.auraSize
    local numAuras = #hdr.auras
    local _, orientation = ns.Reverse(db.auraGrowth)

    local p1 = ns.Reverse(db.auraGrowth)
    local p2 = orientation == "VERTICAL" and "LEFT" or "TOP"
    local p = orientation == "VERTICAL" and p1..p2 or p2..p1
    local mp = ns.Reverse(p, orientation)
    local xgap = orientation == "HORIZONTAL" and db.auraGap or 0
    xgap = db.auraGrowth == "RIGHT" and xgap or -xgap

    local ygap = orientation == "VERTICAL" and db.auraGap or 0
    ygap = db.auraGrowth == "TOP" and ygap or -ygap

    for i=1, numAuras do
        local btn = hdr.auras[i]
        btn:ClearAllPoints()
        btn:SetSize(size, size)
        if i > 1 then
            local prev = hdr.auras[i-1]
            btn:SetPoint(p, prev, mp, xgap, ygap)
        else
            btn:SetPoint(p, hdr, p, 0, 0)
        end
    end
end

local AddAuraFrameToHeader = function(self, auraFrame)
    table.insert(self.auras, auraFrame)
    self:RepositionAuraFrames()
end
function NugPlateAuras:CreateHeader(parent)
    local hdr = CreateFrame("Frame", "$parentNPAHeader", parent)
    parent.NugPlateAurasFrame = hdr

    -- local t = hdr:CreateTexture("ARTWORK")
    -- t:SetTexture("Interface\\BUTTONS\\WHITE8X8")
    -- t:SetAllPoints(hdr)

    hdr:SetSize(10,10)
    if db.attachPoint == "TOP" then
        -- hdr:SetPoint("BOTTOM", parent, "TOP", db.npOffsetX, db.npOffsetY)
        hdr:SetPoint(ns.Reverse(db.attachPoint), parent, db.attachPoint, db.npOffsetX, db.npOffsetY)
    else
        hdr:SetPoint(ns.Reverse(db.attachPoint), parent, db.attachPoint, db.npOffsetX, db.npOffsetY)
    end
    hdr.auras = { }
    hdr.AddAura = AddAuraFrameToHeader
    hdr.RepositionAuraFrames = RepositionAuraFrames
    if db.enableBuffGains then
        hdr.iconPool = NugPlateAuras:CreateFloatingIconPool(hdr)
    end
    return hdr
end


local function MakeFakeAuraFromID(spellID, filter)
    local now = GetTime()
    local name, rank, icon, castTime, minRange, maxRange, spellId = GetSpellInfo(spellID)
    local duration = nil
    local expirationTime = nil
    return { name, icon, 1, nil, duration, expirationTime, nil, nil, nil, spellID }
end

local FakeAuras = {
    HELPFUL = {
        MakeFakeAuraFromID(122470, "HELPFUL"), -- karma
        MakeFakeAuraFromID(122278, "HELPFUL"), -- Dampen Harm
        MakeFakeAuraFromID(871, "HELPFUL"), -- Shield Wall
        MakeFakeAuraFromID(1715, "HELPFUL"), -- Hamstring
        MakeFakeAuraFromID(47536, "HELPFUL"), -- Rapture
        MakeFakeAuraFromID(194249, "HELPFUL"), -- Voidform
        MakeFakeAuraFromID(1044, "HELPFUL"), -- Freedom
        MakeFakeAuraFromID(8178, "HELPFUL"), -- Grounding
        MakeFakeAuraFromID(5277, "HELPFUL"), -- Evasion
    },
    HARMFUL = {
        MakeFakeAuraFromID(119381, "HARMFUL"), -- Leg sweep
        MakeFakeAuraFromID(853, "HARMFUL"), -- Hammer of Justice
        MakeFakeAuraFromID(115078, "HARMFUL"), -- Paralysis
        MakeFakeAuraFromID(118, "HARMFUL"), -- Polymorph
        MakeFakeAuraFromID(23920, "HARMFUL"), -- Spell Reflection
        MakeFakeAuraFromID(5246, "HARMFUL"), -- Intimidating Shout
        MakeFakeAuraFromID(15487, "HARMFUL"), -- Silence
        MakeFakeAuraFromID(64695, "HARMFUL"), -- Earthgrab Totem
    }
}

local FakeAuraSlots = {
    HARMFUL = {},
    HELPFUL = {},
}
local function GenFakeSlots()
    local uniqueTable = {}
    local filters = { "HELPFUL", "HARMFUL" }
    for _, filter in ipairs(filters) do
        local stock = FakeAuras[filter]
        local auras = FakeAuraSlots[filter]
        local num = math.random(3)
        table.wipe(auras)
        for i=1,num do
            local index
            local data
            repeat
                index = math.random(#stock)
                data = stock[index]
            until not uniqueTable[index]

            local now = GetTime()
            local duration = math.random(8)+8
            data[5] = duration
            data[6] = now+duration

            uniqueTable[index] = true
            table.insert(auras, data)
        end
    end
end
local function TestUnitAura(unit, index, filter)
    local slot = FakeAuraSlots[filter][index]
    FAKESLOTS = FakeAuraSlots
    if slot then return unpack(slot) end
end


local sortfunc = function(a,b) return a[3] > b[3] end
local orderedAuras = {}
function NugPlateAuras:UNIT_AURA(event, unit)
    if activePlateUnits[unit] then
        local np = C_NamePlate.GetNamePlateForUnit(unit)
        local hdr = np.NugPlateAurasFrame
        local PRIORITY_THRESHOLD = db.priorityThreshold
        local auras = hdr.auras

        table.wipe(orderedAuras)

        for i=1, 100 do
            local name, icon, count, debuffType, duration, expirationTime, caster, _,_, spellID, canApplyAura, isBossAura = UnitAura(unit, i, "HARMFUL")
            if not name then break end

            local prio, spellType = LibAuraTypes.GetAuraInfo(spellID, "ENEMY")
            if prio and prio > PRIORITY_THRESHOLD then
                table.insert(orderedAuras, { "HARMFUL", i, prio})
            end
        end
        -- TODO: Combine after testing in classic
        for i=1, 100 do
            local name, icon, count, debuffType, duration, expirationTime, caster, _,_, spellID, canApplyAura, isBossAura = UnitAura(unit, i, "HELPFUL")
            if not name then break end

            local prio, spellType = LibAuraTypes.GetAuraInfo(spellID, "ENEMY")
            if prio and prio > PRIORITY_THRESHOLD then
                table.insert(orderedAuras, { "HELPFUL", i, prio})
            end
        end

        if UnitIsPlayer(unit) then
            local isLocked = LibSpellLocks:GetSpellLockInfo(unit)
            if isLocked then
                table.insert(orderedAuras, { "LibSpellLocks", -1, LibAuraTypes.GetAuraTypePriority("SILENCE", "ENEMY") })
            end
        end

        table.sort(orderedAuras, sortfunc)

        local shown = 0
        local headerLength = 0
        local AURA_MAX_DISPLAY = db.maxAuras

        for i=1,100 do
            if shown == AURA_MAX_DISPLAY then break end

            local auraTable = orderedAuras[i]
            if not auraTable then
                for j=i,AURA_MAX_DISPLAY do
                    if auras[j] then auras[j]:Hide()
                    else break end
                end
                break
            end

            local filter, index, priority = unpack(auraTable)
            local name, icon, _, debuffType, duration, expirationTime, _, _,_, spellID
            if index == -1 then
                spellID, name, icon, duration, expirationTime = LibSpellLocks:GetSpellLockInfo(unit)
            else
                name, icon, _, debuffType, duration, expirationTime, _, _,_, spellID = UnitAura(unit, index, filter)
            end

            local btn = auras[i]
            if not btn then
                if db.enableMasque then
                    btn = self:CreateMirrorButton(hdr, i)
                else
                    btn = self:CreateSimpleButton(hdr, i)
                end
                hdr:AddAura(btn)
            end

            btn.icon:SetTexture(icon)
            btn.cooldown:SetCooldown(expirationTime-duration, duration)
            local scale = 0.8 + 1.2*priority/100
            btn:SetScale(scale)

            if priority >= 90 then
                -- LibCustomGlow.AutoCastGlow_Start(btn,{1,1,1,1}, 12, 0.3, 0.7, 0, 0, nil, nil )
                local thickness = 2
                local freq = 0.3
                local length = 1
                LibCustomGlow.PixelGlow_Start(btn,{1,1,1,1}, 12, freq, length, thickness, 0, 0, nil, nil )
            else
                -- LibCustomGlow.AutoCastGlow_Stop(btn)
                LibCustomGlow.PixelGlow_Stop(btn)
            end

            btn:Show()

            headerLength = headerLength + (db.auraSize*scale)
            if shown > 0 then
                headerLength = headerLength + db.auraGap
            end

            shown = shown + 1

        end

        if shown > 0 then
            local _, orientation = ns.Reverse(db.auraGrowth)
            if orientation == "HORIZONTAL" then
                hdr:SetWidth(headerLength)
                hdr:SetHeight(10)
            else
                hdr:SetHeight(headerLength)
                hdr:SetWidth(10)
            end
            -- hdr:Show()
        else
            hdr:SetWidth(10)
            hdr:SetHeight(10)
            -- hdr:Hide()
        end
    end
end

function NugPlateAuras:ForEachNameplate(func)
    for unit in pairs(activePlateUnits) do
        local np = C_NamePlate.GetNamePlateForUnit(unit)
        if np then
            func(unit, np)
        end
    end
end

function NugPlateAuras.ReconfigureHeader(unit, np)
    local hdr = np.NugPlateAurasFrame
    local curMax = db.maxAuras
    local numAuras = #hdr.auras
    if numAuras > curMax then
        for i=curMax, #hdr.auras do
            hdr.auras[i]:Hide()
        end
    end

    hdr:ClearAllPoints()
    hdr:SetPoint(ns.Reverse(db.attachPoint), hdr:GetParent(), db.attachPoint, db.npOffsetX, db.npOffsetY)
    -- hdr:SetPoint("BOTTOM", hdr:GetParent(), "TOP", db.npOffsetX, db.npOffsetY)

    hdr:RepositionAuraFrames()

    NugPlateAuras:UNIT_AURA(nil, unit)
end

function NugPlateAuras.UpdateAuras(unit, np)
    NugPlateAuras:UNIT_AURA(nil, unit)
end

-- Only for Retail
function NugPlateAuras:COMBAT_LOG_EVENT_UNFILTERED(event)
    local timestamp, eventType, hideCaster,
    srcGUID, srcName, srcFlags, srcFlags2,
    dstGUID, dstName, dstFlags, dstFlags2,
    spellID, spellName, spellSchool, auraType = CombatLogGetCurrentEventInfo()

    local PlateUnit = PlateGUIDtoUnit[dstGUID]
    if PlateUnit then
        if eventType == "SPELL_AURA_APPLIED" or eventType == "SPELL_AURA_REFRESH" then
            if auraType == "BUFF" then
                self:UNIT_AURA_GAINED(event, PlateUnit, spellID, auraType)
            end
        end
    end
end

function NugPlateAuras:TestFloatingIcons()
    local unit
    for i=1,20 do
        unit = "nameplate"..i
        if UnitExists(unit) and UnitReaction(unit, "player") < 5 then break end
    end
    self:UNIT_AURA_GAINED(nil, unit, 17, "BUFF")
end

function NugPlateAuras:TestAuras()
    local unit
    for i=1,20 do
        unit = "nameplate"..i
        if UnitExists(unit) and UnitReaction(unit, "player") < 5 then break end
    end

    UnitAura = TestUnitAura
    GenFakeSlots()
    self:UNIT_AURA(nil, unit)
    UnitAura = _G.UnitAura
end

function NugPlateAuras:UNIT_AURA_GAINED(event, unit, spellID, auraType)
    if activePlateUnits[unit] then
        local np = C_NamePlate.GetNamePlateForUnit(unit)
        local hdr = np.NugPlateAurasFrame
        local f, isNew = hdr.iconPool:Acquire()

        local name, _, texture = GetSpellInfo(spellID)
        f.icon:SetTexture(texture)
        f:Show()
        f.ag:Play()
    end
end


function NugPlateAuras:SpawnIconLine(unit)
    self:CreateLastSpellIconLine()
    self:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", unit)
    return self
end


local helpMessage = {
    "|cff00ff00/npa gui|r",
}


NugPlateAuras.Commands = {
    ["gui"] = function(v)
        if not NugPlateAuras.optionsPanel then
            NugPlateAuras.optionsPanel = NugPlateAuras:CreateGUI()
        end
        InterfaceOptionsFrame_OpenToCategory("NugPlateAuras")
        InterfaceOptionsFrame_OpenToCategory("NugPlateAuras")
    end,
}

function NugPlateAuras.SlashCmd(msg)
    local k,v = string.match(msg, "([%w%+%-%=]+) ?(.*)")
    if not k or k == "help" then
        print("Usage:")
        for k,v in ipairs(helpMessage) do
            print(" - ",v)
        end
    end
    if NugPlateAuras.Commands[k] then
        NugPlateAuras.Commands[k](v)
    end
end

function NugPlateAuras:HookOptionsFrame()
    CreateFrame('Frame', nil, InterfaceOptionsFrame):SetScript('OnShow', function(frame)
        frame:SetScript('OnShow', nil)

        if not self.optionsPanel then
            self.optionsPanel = self:CreateGUI()
        end
    end)
end

ns.L = setmetatable({}, {
    __index = function(t, k)
        -- print(string.format('L["%s"] = ""',k:gsub("\n","\\n")));
        return k
    end,
    __call = function(t,k) return t[k] end,
})
