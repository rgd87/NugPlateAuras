local addonName, ns = ...
local L = ns.L

function NugPlateAuras:CreateGUI()
    local opt = {
        type = 'group',
        name = "NugPlateAuras Settings",
        order = 1,
        args = {
            testGains = {
                name = L"Test Buff Gains",
                disabled = function() return not NugPlateAuras.db.profile.enableBuffGains end,
                width = 1.5,
                type = "execute",
                desc = "At least one enemy nameplate should be visible",
                func = function() NugPlateAuras:TestFloatingIcons() end,
                order = 0.1,
            },

            testAuras = {
                name = L"Test Auras",
                type = "execute",
                width = 1.5,
                desc = "At least one enemy nameplate should be visible",
                func = function() NugPlateAuras:TestAuras() end,
                order = 0.2,
            },
            masque = {
                name = L"Enable Masque styling",
                type = "toggle",
                order = 0.8,
                confirm = true,
                confirmText = L"Warning: Requires UI reloading.",
                get = function(info) return NugPlateAuras.db.profile.enableMasque end,
                set = function(info, v)
                    NugPlateAuras.db.profile.enableMasque = not NugPlateAuras.db.profile.enableMasque
                    ReloadUI()
                end
            },

            debuffs = {
                type = 'group',
                name = "Debuffs",
                guiInline = true,
                order = 2,
                args = {
                    maxAuras = {
                        name = L"Max Auras",
                        width = "full",
                        type = "range",
                        get = function(info) return NugPlateAuras.db.profile.debuffs.maxAuras end,
                        set = function(info, v)
                            NugPlateAuras.db.profile.debuffs.maxAuras = tonumber(v)
                            NugPlateAuras:ForEachNameplate(NugPlateAuras.ReconfigureHeaders)
                        end,
                        min = 1,
                        max = 8,
                        step = 1,
                        order = 1,
                    },
                    attachPoint = {
                        name = "Attachment Point",
                        type = 'select',
                        width = 1.5,
                        order = 1.1,
                        values = {
                            TOP = "TOP",
                            LEFT = "LEFT",
                            RIGHT = "RIGHT",
                        },
                        get = function(info)
                            return NugPlateAuras.db.profile.debuffs.attachPoint
                        end,
                        set = function(info, v)
                            NugPlateAuras.db.profile.debuffs.attachPoint = v
                            NugPlateAuras:ForEachNameplate(NugPlateAuras.ReconfigureHeaders)
                        end,
                    },
                    auraGrowth = {
                        name = "Aura Growth",
                        type = 'select',
                        width = 1.5,
                        order = 1.2,
                        values = {
                            TOP = "TOP",
                            LEFT = "LEFT",
                            RIGHT = "RIGHT",
                            BOTTOM = "BOTTOM",
                        },
                        get = function(info)
                            return NugPlateAuras.db.profile.debuffs.auraGrowth
                        end,
                        set = function(info, v)
                            NugPlateAuras.db.profile.debuffs.auraGrowth = v
                            NugPlateAuras:ForEachNameplate(NugPlateAuras.ReconfigureHeaders)
                        end,
                    },
                    npOffsetX = {
                        name = L"Nameplate X Offset",
                        type = "range",
                        get = function(info) return NugPlateAuras.db.profile.debuffs.npOffsetX end,
                        set = function(info, v)
                            NugPlateAuras.db.profile.debuffs.npOffsetX = tonumber(v)
                            NugPlateAuras:ForEachNameplate(NugPlateAuras.ReconfigureHeaders)
                        end,
                        min = -150,
                        max = 150,
                        step = 0.1,
                        order = 2,
                    },
                    npOffsetY = {
                        name = L"Nameplate Y Offset",
                        type = "range",
                        get = function(info) return NugPlateAuras.db.profile.debuffs.npOffsetY end,
                        set = function(info, v)
                            NugPlateAuras.db.profile.debuffs.npOffsetY = tonumber(v)
                            NugPlateAuras:ForEachNameplate(NugPlateAuras.ReconfigureHeaders)
                        end,
                        min = -150,
                        max = 150,
                        step = 0.1,
                        order = 3,
                    },

                    priorityThreshold = {
                        name = L"Priority Threshold".." (PvP)",
                        width = "full",
                        type = "range",
                        get = function(info) return NugPlateAuras.db.profile.debuffs.priorityThreshold end,
                        set = function(info, v)
                            NugPlateAuras.db.profile.debuffs.priorityThreshold = tonumber(v)
                            NugPlateAuras:UpdateThreshold()
                            NugPlateAuras:ForEachNameplate(NugPlateAuras.UpdateAuras)
                        end,
                        min = 1,
                        max = 100,
                        step = 1,
                        order = 4,
                    },

                    priorityThresholdPVE = {
                        name = L"Priority Threshold".." (PvE)",
                        width = "full",
                        type = "range",
                        get = function(info) return NugPlateAuras.db.profile.debuffs.priorityThresholdPVE end,
                        set = function(info, v)
                            NugPlateAuras.db.profile.debuffs.priorityThresholdPVE = tonumber(v)
                            NugPlateAuras:UpdateThreshold()
                            NugPlateAuras:ForEachNameplate(NugPlateAuras.UpdateAuras)
                        end,
                        min = 1,
                        max = 100,
                        step = 1,
                        order = 4.5,
                    },


                    baseAuraSize = {
                        name = L"Base Aura Size",
                        width = "double",
                        type = "range",
                        get = function(info) return NugPlateAuras.db.profile.debuffs.auraSize end,
                        set = function(info, v)
                            NugPlateAuras.db.profile.debuffs.auraSize = tonumber(v)
                            NugPlateAuras:ForEachNameplate(NugPlateAuras.ReconfigureHeaders)
                        end,
                        min = 1,
                        max = 100,
                        step = 1,
                        order = 5,
                    },
                    auraGap = {
                        name = L"Aura Gap",
                        type = "range",
                        get = function(info) return NugPlateAuras.db.profile.debuffs.auraOffsetX end,
                        set = function(info, v)
                            NugPlateAuras.db.profile.debuffs.auraOffsetX = tonumber(v)
                            NugPlateAuras:ForEachNameplate(NugPlateAuras.ReconfigureHeaders)
                        end,
                        min = -30,
                        max = 30,
                        step = 0.1,
                        order = 6,
                    },
                },
            },
            splitAuras = {
                name = L"Split Buffs",
                type = "toggle",
                order = 3.8,
                get = function(info) return NugPlateAuras.db.profile.splitAuras end,
                set = function(info, v)
                    NugPlateAuras.db.profile.splitAuras = not NugPlateAuras.db.profile.splitAuras
                    NugPlateAuras:ForEachNameplate(NugPlateAuras.ReconfigureHeaders)
                end
            },
            buffs = {
                type = 'group',
                name = "Buffs",
                disabled = function() return not NugPlateAuras.db.profile.splitAuras end,
                guiInline = true,
                order = 4,
                args = {
                    maxAuras = {
                        name = L"Max Auras",
                        width = "full",
                        type = "range",
                        get = function(info) return NugPlateAuras.db.profile.buffs.maxAuras end,
                        set = function(info, v)
                            NugPlateAuras.db.profile.buffs.maxAuras = tonumber(v)
                            NugPlateAuras:ForEachNameplate(NugPlateAuras.ReconfigureHeaders)
                        end,
                        min = 1,
                        max = 8,
                        step = 1,
                        order = 1,
                    },
                    attachPoint = {
                        name = "Attachment Point",
                        type = 'select',
                        width = 1.5,
                        order = 1.1,
                        values = {
                            TOP = "TOP",
                            LEFT = "LEFT",
                            RIGHT = "RIGHT",
                        },
                        get = function(info)
                            return NugPlateAuras.db.profile.buffs.attachPoint
                        end,
                        set = function(info, v)
                            NugPlateAuras.db.profile.buffs.attachPoint = v
                            NugPlateAuras:ForEachNameplate(NugPlateAuras.ReconfigureHeaders)
                        end,
                    },
                    auraGrowth = {
                        name = "Aura Growth",
                        type = 'select',
                        width = 1.5,
                        order = 1.2,
                        values = {
                            TOP = "TOP",
                            LEFT = "LEFT",
                            RIGHT = "RIGHT",
                            BOTTOM = "BOTTOM",
                        },
                        get = function(info)
                            return NugPlateAuras.db.profile.buffs.auraGrowth
                        end,
                        set = function(info, v)
                            NugPlateAuras.db.profile.buffs.auraGrowth = v
                            NugPlateAuras:ForEachNameplate(NugPlateAuras.ReconfigureHeaders)
                        end,
                    },
                    npOffsetX = {
                        name = L"Nameplate X Offset",
                        type = "range",
                        get = function(info) return NugPlateAuras.db.profile.buffs.npOffsetX end,
                        set = function(info, v)
                            NugPlateAuras.db.profile.buffs.npOffsetX = tonumber(v)
                            NugPlateAuras:ForEachNameplate(NugPlateAuras.ReconfigureHeaders)
                        end,
                        min = -150,
                        max = 150,
                        step = 0.1,
                        order = 2,
                    },
                    npOffsetY = {
                        name = L"Nameplate Y Offset",
                        type = "range",
                        get = function(info) return NugPlateAuras.db.profile.buffs.npOffsetY end,
                        set = function(info, v)
                            NugPlateAuras.db.profile.buffs.npOffsetY = tonumber(v)
                            NugPlateAuras:ForEachNameplate(NugPlateAuras.ReconfigureHeaders)
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
                        get = function(info) return NugPlateAuras.db.profile.buffs.priorityThreshold end,
                        set = function(info, v)
                            NugPlateAuras.db.profile.buffs.priorityThreshold = tonumber(v)
                            NugPlateAuras:UpdateThreshold()
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
                        get = function(info) return NugPlateAuras.db.profile.buffs.auraSize end,
                        set = function(info, v)
                            NugPlateAuras.db.profile.buffs.auraSize = tonumber(v)
                            NugPlateAuras:ForEachNameplate(NugPlateAuras.ReconfigureHeaders)
                        end,
                        min = 1,
                        max = 100,
                        step = 1,
                        order = 5,
                    },
                    auraGap = {
                        name = L"Aura Gap",
                        type = "range",
                        get = function(info) return NugPlateAuras.db.profile.buffs.auraOffsetX end,
                        set = function(info, v)
                            NugPlateAuras.db.profile.buffs.auraOffsetX = tonumber(v)
                            NugPlateAuras:ForEachNameplate(NugPlateAuras.ReconfigureHeaders)
                        end,
                        min = -30,
                        max = 30,
                        step = 0.1,
                        order = 6,
                    },
                },
            },
            buffGains = {
                name = L"Enable Buff Gains",
                type = "toggle",
                width = "double",
                order = 6,
                confirm = true,
                confirmText = L"Warning: Requires UI reloading.",
                get = function(info) return NugPlateAuras.db.profile.enableBuffGains end,
                set = function(info, v)
                    NugPlateAuras.db.profile.enableBuffGains = not NugPlateAuras.db.profile.enableBuffGains
                    ReloadUI()
                end
            },
            buffGainsOpts = {
                type = 'group',
                name = "Buffs",
                disabled = function() return not NugPlateAuras.db.profile.enableBuffGains end,
                guiInline = true,
                order = 7,
                args = {
                    npOffsetX = {
                        name = L"Nameplate X Offset",
                        type = "range",
                        get = function(info) return NugPlateAuras.db.profile.buffGains.npOffsetX end,
                        set = function(info, v)
                            NugPlateAuras.db.profile.buffGains.npOffsetX = tonumber(v)
                            NugPlateAuras:ForEachNameplate(NugPlateAuras.ReconfigureHeaders)
                        end,
                        min = -150,
                        max = 150,
                        step = 0.1,
                        order = 2,
                    },
                    npOffsetY = {
                        name = L"Nameplate Y Offset",
                        type = "range",
                        get = function(info) return NugPlateAuras.db.profile.buffGains.npOffsetY end,
                        set = function(info, v)
                            NugPlateAuras.db.profile.buffGains.npOffsetY = tonumber(v)
                            NugPlateAuras:ForEachNameplate(NugPlateAuras.ReconfigureHeaders)
                        end,
                        min = -150,
                        max = 150,
                        step = 0.1,
                        order = 3,
                    },

                    baseAuraSize = {
                        name = L"Base Aura Size",
                        width = "double",
                        type = "range",
                        get = function(info) return NugPlateAuras.db.profile.buffGains.auraSize end,
                        set = function(info, v)
                            NugPlateAuras.db.profile.buffGains.auraSize = tonumber(v)
                            NugPlateAuras:ForEachNameplate(NugPlateAuras.ReconfigureHeaders)
                        end,
                        min = 1,
                        max = 100,
                        step = 1,
                        order = 5,
                    },
                },
            },
        },
    }

    local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")
    AceConfigRegistry:RegisterOptionsTable("NugPlateAurasOptions", opt)

    local AceConfigDialog = LibStub("AceConfigDialog-3.0")
    local panelFrame = AceConfigDialog:AddToBlizOptions("NugPlateAurasOptions", "NugPlateAuras")

    return panelFrame
end

