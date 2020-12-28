local addonName, ns = ...
local L = ns.L

function NugPlateAuras:CreateGUI()
    local opt = {
        type = 'group',
        name = "NugPlateAuras Settings",
        order = 1,
        args = {
            masque = {
                name = L"Enable Masque styling",
                type = "toggle",
                order = 0.8,
                confirm = true,
                confirmText = L"Warning: Requires UI reloading.",
                get = function(info) return NugPlateAurasDB.enableMasque end,
                set = function(info, v)
                    NugPlateAurasDB.enableMasque = not NugPlateAurasDB.enableMasque
                    ReloadUI()
                end
            },
            maxAuras = {
                name = L"Max Auras",
                width = "full",
                type = "range",
                get = function(info) return NugPlateAurasDB.maxAuras end,
                set = function(info, v)
                    NugPlateAurasDB.maxAuras = tonumber(v)
                    NugPlateAuras:ForEachNameplate(NugPlateAuras.ReconfigureHeader)
                end,
                min = 1,
                max = 8,
                step = 1,
                order = 1,
            },
            npOffsetX = {
                name = L"Nameplate X Offset",
                type = "range",
                get = function(info) return NugPlateAurasDB.npOffsetX end,
                set = function(info, v)
                    NugPlateAurasDB.npOffsetX = tonumber(v)
                    NugPlateAuras:ForEachNameplate(NugPlateAuras.ReconfigureHeader)
                end,
                min = -150,
                max = 150,
                step = 0.1,
                order = 2,
            },
            npOffsetY = {
                name = L"Nameplate Y Offset",
                type = "range",
                get = function(info) return NugPlateAurasDB.npOffsetY end,
                set = function(info, v)
                    NugPlateAurasDB.npOffsetY = tonumber(v)
                    NugPlateAuras:ForEachNameplate(NugPlateAuras.ReconfigureHeader)
                end,
                min = -150,
                max = 150,
                step = 0.1,
                order = 3,
            },

            priorityThreshold = {
                name = L"Priority Threshold",
                width = "full",
                type = "range",
                get = function(info) return NugPlateAurasDB.priorityThreshold end,
                set = function(info, v)
                    NugPlateAurasDB.priorityThreshold = tonumber(v)
                    NugPlateAuras:ForEachNameplate(NugPlateAuras.UpdateAuras)
                end,
                min = 1,
                max = 100,
                step = 1,
                order = 4,
            },

            baseAuraSize = {
                name = L"Base Aura Size",
                width = "double",
                type = "range",
                get = function(info) return NugPlateAurasDB.auraSize end,
                set = function(info, v)
                    NugPlateAurasDB.auraSize = tonumber(v)
                    NugPlateAuras:ForEachNameplate(NugPlateAuras.ReconfigureHeader)
                end,
                min = 1,
                max = 100,
                step = 1,
                order = 5,
            },
            auraGap = {
                name = L"Aura Gap",
                type = "range",
                get = function(info) return NugPlateAurasDB.auraOffsetX end,
                set = function(info, v)
                    NugPlateAurasDB.auraOffsetX = tonumber(v)
                    NugPlateAuras:ForEachNameplate(NugPlateAuras.ReconfigureHeader)
                end,
                min = -30,
                max = 30,
                step = 0.1,
                order = 6,
            },
            buffGains = {
                name = L"Enable Buff Gains",
                type = "toggle",
                width = "double",
                order = 7,
                confirm = true,
                confirmText = L"Warning: Requires UI reloading.",
                get = function(info) return NugPlateAurasDB.enableBuffGains end,
                set = function(info, v)
                    NugPlateAurasDB.enableBuffGains = not NugPlateAurasDB.enableBuffGains
                    ReloadUI()
                end
            },
            testGains = {
                name = L"Test Buff Gains",
                disabled = function() return not NugPlateAurasDB.enableBuffGains end,
                type = "execute",
                desc = "At least one enemy nameplate should be visible",
                func = function() NugPlateAuras:TestFloatingIcons() end,
                order = 8,
            },

            testAuras = {
                name = L"Test Auras",
                type = "execute",
                desc = "At least one enemy nameplate should be visible",
                func = function() NugPlateAuras:TestAuras() end,
                order = 9,
            },

        },
    }

    local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")
    AceConfigRegistry:RegisterOptionsTable("NugPlateAurasOptions", opt)

    local AceConfigDialog = LibStub("AceConfigDialog-3.0")
    local panelFrame = AceConfigDialog:AddToBlizOptions("NugPlateAurasOptions", "NugPlateAuras")

    return panelFrame
end

