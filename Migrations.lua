local addonName, helpers = ...

do
    local CURRENT_DB_VERSION = 1
    function NugPlateAuras:DoMigrations(db)
        if not next(db) or db.DB_VERSION == CURRENT_DB_VERSION then -- skip if db is empty or current
            db.DB_VERSION = CURRENT_DB_VERSION
            return
        end

        if db.DB_VERSION == nil then

            db.profiles = {
                Default = {
                    buffs = {},
                    debuffs = {},
                }
            }
            local default_profile = db.profiles["Default"]
            default_profile.enableMasque = db.enableMasque
            default_profile.enableBuffGains = db.enableBuffGains
            default_profile.splitAuras = db.splitAuras

            default_profile.floatingOffsetX = db.floatingOffsetX
            default_profile.floatingOffsetY = db.enableBuffGains

            default_profile.debuffs.attachPoint = db.attachPoint
            default_profile.debuffs.auraGrowth = db.auraGrowth
            default_profile.debuffs.maxAuras = db.maxAuras
            default_profile.debuffs.priorityThreshold = db.priorityThreshold
            default_profile.debuffs.auraSize = db.auraSize
            default_profile.debuffs.auraGap = db.auraGap
            default_profile.debuffs.npOffsetX = db.npOffsetX
            default_profile.debuffs.npOffsetY = db.npOffsetY

            db.enableMasque = nil
            db.enableBuffGains = nil
            db.splitAuras = nil
            db.floatingOffsetX = nil
            db.enableBuffGains = nil
            db.attachPoint = nil
            db.auraGrowth = nil
            db.maxAuras = nil
            db.priorityThreshold = nil
            db.auraSize = nil
            db.auraGap = nil
            db.npOffsetX = nil
            db.npOffsetY = nil

            db.DB_VERSION = 1
        end

        db.DB_VERSION = CURRENT_DB_VERSION
    end
end
