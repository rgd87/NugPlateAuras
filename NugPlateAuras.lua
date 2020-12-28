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
    enableMasque = false,
    enableBuffGains = true,
    maxAuras = 3,
    priorityThreshold = 50,
    auraSize = 25,
    auraOffsetX = 2,
    npOffsetX = 0,
    npOffsetY = 10,
    floatingOffsetX = 0,
    floatingOffsetY = -15,
}

local function SetupDefaults(t, defaults)
    for k,v in pairs(defaults) do
        if type(v) == "table" then
            if t[k] == nil then
                t[k] = CopyTable(v)
            else
                SetupDefaults(t[k], v)
            end
        else
            if t[k] == nil then t[k] = v end
        end
    end
end
local function RemoveDefaults(t, defaults)
    for k, v in pairs(defaults) do
        if type(t[k]) == 'table' and type(v) == 'table' then
            RemoveDefaults(t[k], v)
            if next(t[k]) == nil then
                t[k] = nil
            end
        elseif t[k] == v then
            t[k] = nil
        end
    end
    return t
end

function NugPlateAuras.ADDON_LOADED(self,event,arg1)
    if arg1 == addonName then

        NugPlateAurasDB = NugPlateAurasDB or {}
        db = NugPlateAurasDB
        SetupDefaults(NugPlateAurasDB, defaults)
        self:RegisterEvent("PLAYER_LOGOUT")

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
    if UnitIsUnit(unit, "player") or UnitIsFriend(unit, "player") then return end
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

local AddAuraFrameToHeader = function(self, auraFrame)
    local numAuras = #self.auras
    if numAuras > 0 then
        local prev = self.auras[numAuras]
        -- local newIndex = numAuras+1
        -- local isEven = math.fmod(newIndex, 2) == 0

        -- if isEven then
            -- local prev = self.auras[newIndex-2] or self.auras[1]
            auraFrame:SetPoint("BOTTOMLEFT", prev, "BOTTOMRIGHT", db.auraOffsetX, 0)
        -- else
        --     local prev = self.auras[newIndex-2] or self.auras[1]
        --     auraFrame:SetPoint("BOTTOMRIGHT", prev, "BOTTOMLEFT", -db.auraOffsetX, 0)
        -- end
    else
        auraFrame:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", 0, 0)
    end
    table.insert(self.auras, auraFrame)
end
function NugPlateAuras:CreateHeader(parent)
    local hdr = CreateFrame("Frame", "$parentNPAHeader", parent)
    parent.NugPlateAurasFrame = hdr
    hdr:SetSize(10,10)
    hdr:SetPoint("BOTTOM", parent, "TOP", db.npOffsetX, db.npOffsetY)
    hdr.auras = { }
    hdr.AddAura = AddAuraFrameToHeader
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
        local headerWidth = 0
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

            headerWidth = headerWidth + (db.auraSize*scale)
            if shown > 0 then
                headerWidth = headerWidth + db.auraOffsetX
            end

            shown = shown + 1

        end

        if shown > 0 then
            hdr:SetWidth(headerWidth)
            -- hdr:Show()
        else
            hdr:SetWidth(10)
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

    hdr:SetPoint("BOTTOM", hdr:GetParent(), "TOP", db.npOffsetX, db.npOffsetY)

    local size = db.auraSize
    for i=1, numAuras do
        local btn = hdr.auras[i]
        btn:SetSize(size, size)
        if i > 1 then
            local prev = hdr.auras[i-1]
            btn:SetPoint("BOTTOMLEFT", prev, "BOTTOMRIGHT", db.auraOffsetX, 0)
        else
            btn:SetPoint("BOTTOMLEFT", hdr, "BOTTOMLEFT", 0, 0)
        end
    end

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
        if UnitExists(unit) and not UnitIsFriend(unit, "player") then break end
    end
    self:UNIT_AURA_GAINED(nil, unit, 17, "BUFF")
end

function NugPlateAuras:TestAuras()
    local unit
    for i=1,20 do
        unit = "nameplate"..i
        if UnitExists(unit) and not UnitIsFriend(unit, "player") then break end
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
