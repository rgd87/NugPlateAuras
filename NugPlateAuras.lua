local addonName, ns = ...


local NugPlateAuras = CreateFrame("Frame", "NugPlateAuras", UIParent)
NugPlateAuras:SetScript("OnEvent", function(self, event, ...)
    return self[event](self, event, ...)
end)

local isClassic = WOW_PROJECT_ID == WOW_PROJECT_CLASSIC
local isRetail = WOW_PROJECT_ID == WOW_PROJECT_MAINLINE

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

local BUFF_PRIORITY_THRESHOLD
local DEBUFF_PRIORITY_THRESHOLD

local defaults = {
    profile = {
        enableMasque = false,
        enableBuffGains = true,
        splitAuras = true,
        staticSize = false,
        buffs = {
            attachPoint = "RIGHT",
            auraGrowth = "RIGHT",
            maxAuras = 3,
            priorityThreshold = 50,
            auraSize = 21,
            auraGap = 2,
            npOffsetX = 5,
            npOffsetY = 0,
        },
        debuffs = {
            attachPoint = "TOP",
            auraGrowth = "RIGHT",
            maxAuras = 3,
            priorityThreshold = 50,
            priorityThresholdPVE = 50,
            auraSize = 25,
            auraGap = 2,
            npOffsetX = 0,
            npOffsetY = 10,
        },
        buffGains = {
            auraSize = 25,
            npOffsetX = 0,
            npOffsetY = -25,
        },
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

        if db.profile.enableBuffGains then
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

        if Masque and db.profile.enableMasque then
            ns.MasqueGroup = Masque:Group(addonName, "NugPlateAuras")
        end

        self:UpdateThreshold()
        self:RegisterEvent("NAME_PLATE_CREATED")
        self:RegisterEvent("NAME_PLATE_UNIT_ADDED")
        self:RegisterEvent("NAME_PLATE_UNIT_REMOVED")

        self:RegisterEvent("PLAYER_ENTERING_WORLD") -- check instance info

        self:RegisterEvent("UNIT_AURA")

        SLASH_NUGPLATEAURAS1 = "/nugplateauras"
        SLASH_NUGPLATEAURAS2 = "/npa"
        SlashCmdList["NUGPLATEAURAS"] = self.SlashCmd

        NugPlateAuras:HookOptionsFrame()
    end
end

function NugPlateAuras:Reconfigure()
    NugPlateAuras:ForEachNameplate(NugPlateAuras.ReconfigureHeaders)
end

function NugPlateAuras.NAME_PLATE_CREATED(self, event, np)
    if not np.NugPlateHeaders then
        np.NugPlateHeaders = {
            buffs = self:CreateHeader(np, "buffs"),
            debuffs = self:CreateHeader(np, "debuffs"),
        }

        local headers = np.NugPlateHeaders
        if db.profile.enableBuffGains then
            np.NugPlateHeaders["buffGains"] = NugPlateAuras:CreateFloatingIconPool(np)
            -- np.NugPlateHeaders["buffGains"].auras = {}
        end
    end
end

function NugPlateAuras.NAME_PLATE_UNIT_ADDED(self, event, unit)
    if UnitIsUnit(unit, "player") or UnitReaction(unit, "player") >= 5 then return end
    local np = C_NamePlate.GetNamePlateForUnit(unit)
    activePlateUnits[unit] = true
    PlateGUIDtoUnit[UnitGUID(unit)] = unit
    self:UNIT_AURA(event, unit)
    -- if not np.NugPlateHeaders then
    --     self:CreateHeader(np)
    -- end
end

function NugPlateAuras.NAME_PLATE_UNIT_REMOVED(self, event, unit)
    local np = C_NamePlate.GetNamePlateForUnit(unit)
    activePlateUnits[unit] = nil
    PlateGUIDtoUnit[UnitGUID(unit)] = nil
    if np.NugPlateHeaders then
        for headerType, hdr in pairs(np.NugPlateHeaders) do
            if hdr.auras then
                for _, aura in ipairs(hdr.auras) do
                    aura:Hide()
                end
            end
        end
    end
end


local PlateHeader = {}
function PlateHeader.RepositionAuraFrames(hdr)
    local dbh = db.profile[hdr.headerType]
    local size = dbh.auraSize
    local numAuras = #hdr.auras
    local _, orientation = ns.Reverse(dbh.auraGrowth)

    local p1 = ns.Reverse(dbh.auraGrowth)

    local vJustPoint = dbh.attachPoint == "TOP" and "BOTTOM" or "TOP"

    local p2 = orientation == "VERTICAL" and "LEFT" or vJustPoint
    local p = orientation == "VERTICAL" and p1..p2 or p2..p1
    local mp = ns.Reverse(p, orientation)
    local xgap = orientation == "HORIZONTAL" and dbh.auraGap or 0
    xgap = dbh.auraGrowth == "RIGHT" and xgap or -xgap

    local ygap = orientation == "VERTICAL" and dbh.auraGap or 0
    ygap = dbh.auraGrowth == "TOP" and ygap or -ygap

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

function PlateHeader.AddAura(hdr, auraFrame)
    table.insert(hdr.auras, auraFrame)
    hdr:RepositionAuraFrames()
end


function PlateHeader.Reconfigure(hdr, unit)
    local headerType = hdr.headerType
    local dbh = db.profile[headerType]

    local curMax = dbh.maxAuras
    local numAuras = #hdr.auras
    if numAuras > curMax then
        for i=curMax, #hdr.auras do
            hdr.auras[i]:Hide()
        end
    end

    hdr:ClearAllPoints()
    hdr:SetPoint(ns.Reverse(dbh.attachPoint), hdr:GetParent(), dbh.attachPoint, dbh.npOffsetX, dbh.npOffsetY)

    hdr:RepositionAuraFrames()

    NugPlateAuras:UNIT_AURA(nil, unit)
end

function NugPlateAuras:CreateHeader(parent, headerType)
    local htu = string.upper(headerType)
    local hdr = CreateFrame("Frame", "$parentNPAHeader"..htu, parent)

    Mixin(hdr, PlateHeader)

    local dbh = db.profile[headerType]
    hdr.headerType = headerType

    -- local t = hdr:CreateTexture("ARTWORK")
    -- t:SetTexture("Interface\\BUTTONS\\WHITE8X8")
    -- t:SetAllPoints(hdr)

    hdr:SetSize(10,10)
    if dbh.attachPoint == "TOP" then
        -- hdr:SetPoint("BOTTOM", parent, "TOP", dbh.npOffsetX, dbh.npOffsetY)
        hdr:SetPoint(ns.Reverse(dbh.attachPoint), parent, dbh.attachPoint, dbh.npOffsetX, dbh.npOffsetY)
    else
        hdr:SetPoint(ns.Reverse(dbh.attachPoint), parent, dbh.attachPoint, dbh.npOffsetX, dbh.npOffsetY)
    end
    hdr.auras = { }

    return hdr
end


local function MakeFakeAuraFromID(spellID, filter)
    local now = GetTime()
    local name, rank, icon, castTime, minRange, maxRange, spellId = GetSpellInfo(spellID)
    local duration = nil
    local expirationTime = nil
    local count = 1
    if math.random(4) == 1 then
        count = math.random(5)
    end
    return { name, icon, count, nil, duration, expirationTime, nil, nil, nil, spellID }
end

local FakeAuras
local FakeAuraSlots = {
    HARMFUL = {},
    HELPFUL = {},
}
local function GenFakeSlots()
    if not FakeAuras then
        FakeAuras = {
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
    end

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
local ordered = {
    buffs = {},
    debuffs = {},
}
local orderedAuras = ordered.debuffs
local orderedBuffs = ordered.buffs

local headersMerged = { "debuffs" }
local headersSplit = { "buffs", "debuffs" }

function NugPlateAuras:UNIT_AURA(event, unit)
    if activePlateUnits[unit] then
        local np = C_NamePlate.GetNamePlateForUnit(unit)
        local hdrTable = np.NugPlateHeaders

        table.wipe(orderedBuffs)
        table.wipe(orderedAuras)

        for i=1, 100 do
            local name, icon, count, debuffType, duration, expirationTime, caster, _,_, spellID, canApplyAura, isBossAura = UnitAura(unit, i, "HARMFUL")
            if not name then break end

            local prio, spellType = LibAuraTypes.GetAuraInfo(spellID, "ENEMY")
            if prio and prio > DEBUFF_PRIORITY_THRESHOLD then
                table.insert(orderedAuras, { "HARMFUL", i, prio})
            end
        end

        for i=1, 100 do
            local name, icon, count, debuffType, duration, expirationTime, caster, _,_, spellID, canApplyAura, isBossAura = UnitAura(unit, i, "HELPFUL")
            if not name then break end

            local prio, spellType = LibAuraTypes.GetAuraInfo(spellID, "ENEMY")
            if prio and prio > BUFF_PRIORITY_THRESHOLD then
                table.insert(orderedBuffs, { "HELPFUL", i, prio})
            end
        end

        if UnitIsPlayer(unit) then
            local isLocked = LibSpellLocks:GetSpellLockInfo(unit)
            if isLocked then
                table.insert(orderedAuras, { "LibSpellLocks", -1, LibAuraTypes.GetAuraTypePriority("SILENCE", "ENEMY") })
            end
        end

        local headers
        if not db.profile.splitAuras then
            tAppendAll(orderedAuras, orderedBuffs)
            headers = headersMerged
        else
            headers = headersSplit
            table.sort(orderedBuffs, sortfunc)
        end

        table.sort(orderedAuras, sortfunc)

        local enforced_priority
        if db.profile.staticSize then
            enforced_priority = 70
        end

        for _, headerType in ipairs(headers) do

            local hdr = hdrTable[headerType]
            local shown = 0
            local headerLength = 0
            local dbh = db.profile[headerType]
            local AURA_MAX_DISPLAY = dbh.maxAuras
            local auras = hdr.auras

            for i=1,100 do
                if shown == AURA_MAX_DISPLAY then break end

                local auraTable = ordered[headerType][i]
                if not auraTable then
                    for j=i,AURA_MAX_DISPLAY do
                        if auras[j] then auras[j]:Hide()
                        else break end
                    end
                    break
                end

                local filter, index, priority = unpack(auraTable)
                local name, icon, count, debuffType, duration, expirationTime, _, _,_, spellID
                if index == -1 then
                    spellID, name, icon, duration, expirationTime = LibSpellLocks:GetSpellLockInfo(unit)
                    count = 0
                else
                    name, icon, count, debuffType, duration, expirationTime, _, _,_, spellID = UnitAura(unit, index, filter)
                end

                local btn = auras[i]
                if not btn then
                    if dbh.enableMasque then
                        btn = self:CreateMirrorButton(hdr, dbh, i)
                    else
                        btn = self:CreateSimpleButton(hdr, dbh, i)
                    end
                    hdr:AddAura(btn)
                end

                btn.icon:SetTexture(icon)
                btn.cooldown:SetCooldown(expirationTime-duration, duration)
                btn.stacktext:SetText(count > 1 and count or nil)

                priority = enforced_priority or priority
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

                headerLength = headerLength + (dbh.auraSize*scale)
                if shown > 0 then
                    headerLength = headerLength + dbh.auraGap
                end

                shown = shown + 1

            end

            if shown > 0 then
                local _, orientation = ns.Reverse(dbh.auraGrowth)
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
end

function NugPlateAuras:ForEachNameplate(func)
    for unit in pairs(activePlateUnits) do
        local np = C_NamePlate.GetNamePlateForUnit(unit)
        if np then
            func(unit, np)
        end
    end
end

function NugPlateAuras.ReconfigureHeaders(unit, np)
    local headers = np.NugPlateHeaders
    for headerType, hdr in pairs(headers) do
        hdr:Reconfigure(unit)
    end
    if not NugPlateAuras.db.profile.splitAuras then
        headers.buffs:Hide()
    else
        headers.buffs:Show()
    end
end

function NugPlateAuras:UpdateThreshold()
    local _, instanceType = GetInstanceInfo()
    local isPVPInstance = instanceType == "pvp" or instanceType == "arena"
    local isPVEInstance = instanceType == "party" or instanceType == "raid"

    local isWarModeOn
    if instanceType == "none" then
        if isRetail then
            isWarModeOn = C_PvP.IsWarModeActive()
        else
            isWarModeOn = true -- always on in classic
        end
    end

    local isPVP = isPVPInstance or isWarModeOn

    local db_buffs = db.profile["buffs"]
    local db_debuffs = db.profile["debuffs"]

    BUFF_PRIORITY_THRESHOLD = db_buffs.priorityThreshold
    DEBUFF_PRIORITY_THRESHOLD = isPVP and db_debuffs.priorityThreshold or db_debuffs.priorityThresholdPVE
end
function NugPlateAuras:PLAYER_ENTERING_WORLD()
    self:UpdateThreshold()
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

local sampleBuffsIDs = { 17, 122470, 336126, 336135, 122278, 871, 1715, 47536, 194249, 1044, 8178, 5277, }
function NugPlateAuras:TestFloatingIcons()
    local unit
    for i=1,20 do
        unit = "nameplate"..i
        if UnitExists(unit) and UnitReaction(unit, "player") < 5 then break end
    end
    self:UNIT_AURA_GAINED(nil, unit, sampleBuffsIDs[math.random(#sampleBuffsIDs)], "BUFF")
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
        local headers = np.NugPlateHeaders
        local f, isNew = headers.buffGains.pool:Acquire()

        if spellID == 336126 or spellID == 336135 then -- medallion and adaptation
            f:SetScale(2)
        else
            f:SetScale(1)
        end

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
