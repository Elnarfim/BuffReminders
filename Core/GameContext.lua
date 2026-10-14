local _, BR = ...

-- Maps game events to the caches that each event makes stale, and owns the player flags
-- (combat, rest, level, vehicle). The Display event dispatcher calls HandleEvent before
-- the Display handler runs, so each handler reads fresh values.

---@class GameContextEventSpec
---@field caches? string[] Cache ids to clear, in order
---@field playerOnly? boolean The event applies only when arg1 is "player"
---@field handle? fun(...) Runs after the cache clears, with the event payload

-- The combat flag tracks events, because InCombatLockdown() can lag behind PLAYER_REGEN_DISABLED
-- and ENCOUNTER_START. It gates fighting-dependent behavior, not restriction detection.
local inCombat = false
local inEncounter = false
local isResting = false
local inVehicle = false
local playerLevel = UnitLevel("player")
local maxExpansionLevel = GetMaxLevelForPlayerExpansion()

local SPELL_SET = { "spell", "pet", "stance", "loadout", "petActions" }
local CONTENT_TYPE = { caches = { "contentType" } }
local HEALER = { caches = { "healer" } }
local STANCE = { caches = { "stance" } }

---@type table<string, GameContextEventSpec>
local EVENT_CACHES = {
    PLAYER_ENTERING_WORLD = {
        caches = {
            "contentType",
            "auraTrackable",
            "spell",
            "spec",
            "offHand",
            "pet",
            "stance",
            "loadout",
            "repairSource",
            "durability",
            "petActions",
        },
        handle = function()
            inCombat = InCombatLockdown()
            isResting = IsResting()
            playerLevel = UnitLevel("player")
            maxExpansionLevel = GetMaxLevelForPlayerExpansion()
            inVehicle = UnitInVehicle("player") == true
        end,
    },
    PLAYER_REGEN_DISABLED = {
        handle = function()
            inCombat = true
        end,
    },
    PLAYER_REGEN_ENABLED = {
        handle = function()
            inCombat = inEncounter
        end,
    },
    ENCOUNTER_START = {
        handle = function()
            inEncounter = true
            inCombat = true
        end,
    },
    ENCOUNTER_END = {
        handle = function()
            inEncounter = false
            inCombat = inCombat and InCombatLockdown()
        end,
    },
    PLAYER_UPDATE_RESTING = {
        handle = function()
            isResting = IsResting()
        end,
    },
    PLAYER_LEVEL_UP = {
        handle = function(level)
            playerLevel = level
        end,
    },
    UPDATE_EXPANSION_LEVEL = {
        handle = function()
            maxExpansionLevel = GetMaxLevelForPlayerExpansion()
        end,
    },
    UNIT_ENTERED_VEHICLE = {
        playerOnly = true,
        handle = function()
            inVehicle = true
        end,
    },
    UNIT_EXITED_VEHICLE = {
        playerOnly = true,
        handle = function()
            inVehicle = false
        end,
    },
    GROUP_ROSTER_UPDATE = HEALER,
    GROUP_FORMED = HEALER,
    PLAYER_ROLES_ASSIGNED = HEALER,
    UNIT_PET = { playerOnly = true, caches = { "pet" } },
    UPDATE_SHAPESHIFT_FORM = STANCE,
    UPDATE_SHAPESHIFT_FORMS = STANCE,
    PET_STABLE_UPDATE = { caches = { "petActions" } },
    PLAYER_DIFFICULTY_CHANGED = CONTENT_TYPE,
    CHALLENGE_MODE_START = CONTENT_TYPE,
    CHALLENGE_MODE_COMPLETED = CONTENT_TYPE,
    CHALLENGE_MODE_RESET = CONTENT_TYPE,
    PLAYER_SPECIALIZATION_CHANGED = {
        playerOnly = true,
        caches = { "spell", "spec", "offHand", "pet", "stance", "loadout", "petActions", "consumables" },
    },
    TRAIT_CONFIG_UPDATED = { caches = SPELL_SET },
    SPELLS_CHANGED = { caches = SPELL_SET },
    PLAYER_EQUIPMENT_CHANGED = { caches = { "item", "offHand", "loadout", "durability" } },
    UPDATE_INVENTORY_DURABILITY = { caches = { "durability" } },
    BAG_UPDATE_DELAYED = { caches = { "item", "repairSource", "consumables" } },
    NEW_MOUNT_ADDED = { caches = { "repairSource" } },
}

---@type table<string, fun()>
local invalidators = {}

local GameContext = {}

---Bind a cache id to the function that clears the cache.
---@param id string
---@param fn fun()
function GameContext.RegisterCache(id, fn)
    if invalidators[id] then
        error("GameContext: cache id '" .. id .. "' is already registered", 2)
    end
    invalidators[id] = fn
end

---Clear one cache. An unknown id is a programming error.
---@param id string
function GameContext.Invalidate(id)
    local fn = invalidators[id]
    if not fn then
        error("GameContext: unknown cache id '" .. tostring(id) .. "'", 2)
    end
    fn()
end

---@param ids string[]
local function InvalidateAll(ids)
    for i = 1, #ids do
        GameContext.Invalidate(ids[i])
    end
end

---Apply the EVENT_CACHES entry for the event. Safe to call for every event.
---@param event string
---@param ... any The event payload
function GameContext.HandleEvent(event, ...)
    local entry = EVENT_CACHES[event]
    if not entry then
        return
    end
    if entry.playerOnly and (...) ~= "player" then
        return
    end
    if entry.caches then
        InvalidateAll(entry.caches)
    end
    if entry.handle then
        entry.handle(...)
    end
end

---@return boolean inCombat True in combat or in a boss encounter
function GameContext.IsInCombat()
    return inCombat
end

---@return boolean inEncounter True between ENCOUNTER_START and ENCOUNTER_END
function GameContext.IsInEncounter()
    return inEncounter
end

---@return boolean isResting
function GameContext.IsResting()
    return isResting
end

---@return boolean inVehicle True when the player is in a vehicle
function GameContext.IsInVehicle()
    return inVehicle
end

---@return number playerLevel
function GameContext.GetPlayerLevel()
    return playerLevel
end

---@return number maxExpansionLevel The max level of the player's expansion
function GameContext.GetMaxExpansionLevel()
    return maxExpansionLevel
end

BR.GameContext = GameContext
