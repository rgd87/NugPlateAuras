local addonName, ns = ...

function NugPlateAuras:CreateMirrorButton(parent, index)
    local db = NugPlateAurasDB

    local mirror = CreateFrame("Button", parent:GetName().."AuraFrame"..index, parent, "ActionButtonTemplate")
    mirror:SetHeight(db.auraSize)
    mirror:SetWidth(db.auraSize)

    if ns.MasqueGroup then
        ns.MasqueGroup:AddButton(mirror)
    end
    mirror:Show()

    local cd = mirror.cooldown
    cd:SetReverse(true)
    cd:SetDrawEdge(false)

    mirror:EnableMouse(false)
    mirror:Show()

    return mirror
end

local MakeBorder = function(self, tex, left, right, top, bottom, level)
    local t = self:CreateTexture(nil,"BORDER",nil,level)
    t:SetTexture(tex)
    t:SetPoint("TOPLEFT", self, "TOPLEFT", left, -top)
    t:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -right, bottom)
    return t
end

function NugPlateAuras:CreateSimpleButton(parent, index)
    local db = NugPlateAurasDB

    local f = CreateFrame("Frame", parent:GetName().."AuraFrame"..index, parent)

    f:SetWidth(db.auraSize); f:SetHeight(db.auraSize)

    local blackLayer = MakeBorder(f, "Interface\\BUTTONS\\WHITE8X8", 0, 0, 0, 0, -2)
    blackLayer:SetVertexColor(0,0,0,0.4)
    blackLayer:SetDrawLayer("ARTWORK", -2)

    local border = 1

    local tex = f:CreateTexture(nil,"ARTWORK")
    f.icon = tex
    tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    tex:SetPoint("TOPLEFT", f, "TOPLEFT", border, -border)
    tex:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -border, border)

    local cd = CreateFrame("Cooldown", nil, f, "CooldownFrameTemplate")
    f.cooldown = cd
    -- cd.noCooldownCount = true -- disable OmniCC for this cooldown
    -- cd:SetHideCountdownNumbers(true)
    cd:SetReverse(true)
    cd:SetDrawEdge(false)
    cd:SetPoint("TOPLEFT", border, -border)
    cd:SetPoint("BOTTOMRIGHT", -border, border)

    return f
end

function NugPlateAuras:CreateProgressButton(parent, index)
    local db = NugPlateAurasDB

    local f = CreateFrame("Frame", parent:GetName().."AuraFrame"..index, parent)
    local border = 2.5

    f:SetWidth(db.auraSize-border); f:SetHeight(db.auraSize-border)

    local blackLayer = MakeBorder(f, "Interface\\BUTTONS\\WHITE8X8", 0, 0, 0, 0, -2)
    blackLayer:SetVertexColor(0,0,0,0.4)
    blackLayer:SetDrawLayer("ARTWORK", 2)

    local cd = CreateFrame("Cooldown", nil, f, "CooldownFrameTemplate")
    f.cooldown = cd
    -- cd.noCooldownCount = true -- disable OmniCC for this cooldown
    -- cd:SetHideCountdownNumbers(true)
    -- cd:SetReverse(true)
    cd:SetDrawEdge(false)
    local offset = 1
    cd:SetPoint("TOPLEFT", offset, -offset)
    cd:SetPoint("BOTTOMRIGHT", -offset, offset)
    cd:SetScript("OnCooldownDone", function(self)
        self:GetParent():Hide()
    end)
    cd:SetSwipeColor(0.8, 1, 0.2, 1);
    cd:SetSwipeTexture("Interface\\BUTTONS\\WHITE8X8")

    local tex = f:CreateTexture(nil,"ARTWORK")
    f.icon = tex
    tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    tex:SetPoint("TOPLEFT", f, "TOPLEFT", border, -border)
    tex:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -border, border)

    local iconSubFrame = CreateFrame("Frame", nil, f)
    iconSubFrame:SetAllPoints(f)
    iconSubFrame:SetFrameLevel(8)

    tex:SetParent(iconSubFrame)
    tex:SetDrawLayer("ARTWORK", 5)

    -- local stackframe = CreateFrame("Frame", nil, f)
    -- stackframe:SetAllPoints(f)
    -- local stacktext = stackframe:CreateFontString(nil,"ARTWORK")
    -- stacktext:SetDrawLayer("ARTWORK",1)
    -- local stackFont = LSM:Fetch("font",  Aptechka.db.nameFontName)
    -- local stackFontSize = Aptechka.db.stackFontSize
    -- stacktext:SetFont(stackFont, stackFontSize, "OUTLINE")
    return f
end

local PoolIconResetterFunc = function(pool, f)
    local db = NugPlateAurasDB

    f:SetHeight(25)
    f:SetWidth(25)

    f.ag:Stop()

    local angleRange = 30
    local angle = math.random(0,angleRange)- (angleRange/2)
    local distance = 70
    local translateX = math.sin(math.rad(angle))*distance
    local translateY = math.cos(math.rad(angle))*distance
    f.ag.t1:SetOffset(translateX, translateY)

    local hdr = pool.parent
    f:SetPoint("BOTTOM", hdr, "BOTTOM", db.floatingOffsetX, db.floatingOffsetY)
end

local PoolIconCreationFunc = function(pool)
    local hdr = pool.parent
    local f
    -- if ns.MasqueGroup then
    --     f = CreateFrame("Button", nil, hdr, "ActionButtonTemplate")
    -- else
        f = CreateFrame("Frame", nil, hdr)
    -- end

    f:EnableMouse(false)
    f:SetFrameLevel(6)

    -- f:SetHeight(25)
    -- f:SetWidth(25)

    f:SetPoint("BOTTOM", hdr, "BOTTOM",0, -0)



    -- if ns.MasqueGroup then
        -- ns.MasqueGroup:AddButton(f)
    -- else
        local tex = f:CreateTexture(nil,"ARTWORK", nil, 0)
        f.icon = tex
        tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        tex:SetAllPoints(f)
    -- end

    f.icon:SetTexture("Interface\\Icons\\Spell_Shadow_SacrificialShield")

    local ag = f:CreateAnimationGroup()
    f.ag = ag

    -- local scaleOrigin = "RIGHT"
    local translateX = 0
    local translateY = 100


    -- f:SetAlpha(0)
    -- local s1 = ag:CreateAnimation("Scale")
    -- s1:SetScale(0.01,1)
    -- s1:SetDuration(0)
    -- s1:SetOrigin(scaleOrigin,0,0)
    -- s1:SetOrder(1)

    -- local s2 = ag:CreateAnimation("Scale")
    -- s2:SetScale(100,1)
    -- s2:SetDuration(0.5)
    -- s2:SetOrigin(scaleOrigin,0,0)
    -- s2:SetSmoothing("OUT")
    -- s2:SetOrder(2)

    local a1 = ag:CreateAnimation("Alpha")
    a1:SetFromAlpha(0)
    a1:SetToAlpha(1)
    a1:SetDuration(0.3)
    a1:SetOrder(2)

    local t1 = ag:CreateAnimation("Translation")
    t1:SetOffset(translateX,translateY)
    t1:SetDuration(2)
    t1:SetSmoothing("OUT")
    t1:SetOrder(2)

    local a2 = ag:CreateAnimation("Alpha")
    a2:SetFromAlpha(1)
    a2:SetToAlpha(0)
    a2:SetSmoothing("OUT")
    a2:SetDuration(0.5)
    a2:SetStartDelay(1.5)
    a2:SetOrder(2)

    -- ag.s1 = s1
    -- ag.s2 = s2
    ag.t1 = t1

    ag:SetScript("OnFinished", function(self)
        local icon = self:GetParent()
        icon:Hide()
        pool:Release(icon)
    end)

    return f
end

function NugPlateAuras:CreateFloatingIconPool(hdr)
    local template = nil
    local resetterFunc = PoolIconResetterFunc
    local iconPool = CreateFramePool("Frame", hdr, template, resetterFunc)
    iconPool.creationFunc = PoolIconCreationFunc

    return iconPool
end