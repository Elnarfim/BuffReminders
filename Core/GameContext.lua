local _, BR = ...

-- Maps game events to the caches that each event makes stale.
-- The Display event dispatcher calls HandleEvent before the Display handler runs,
-- so each handler reads fresh values.

---@class GameContextEventSpec
---@field caches string[] Cache ids to clear, in order
---@field playerOnly? boolean The event applies only when arg1 is "player"

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

---Clear the caches that EVENT_CACHES binds to the event. Safe to call for every event.
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
    InvalidateAll(entry.caches)
end

BR.GameContext = GameContext
