-- da_tack: low-profile horse-tack editor. Imports da_horse and exposes a
-- right-docked NUI panel to browse tack categories (saddles, stirrups, bridles…)
-- and equip/remove them, and to save/load tack *loadouts* (owned by the player,
-- applied to a horse later). Edits drive da_horse on a spawned PREVIEW HORSE so
-- you see the tack live, the same way da_wardrobe edits the live player.

local open = false
local previewHorse = nil
-- True when previewHorse is the player's actual mount (not a spawned preview), so
-- despawn never deletes the horse they're riding.
local usingMount = false

local function maskHash(h) return h and (h & 0xFFFFFFFF) or 0 end

-- Strip the HORSE_EQUIPMENT_/HORSE_ boilerplate for a readable label.
local function pretty(s)
    if not s then return nil end
    s = s:gsub("^HORSE_EQUIPMENT_", ""):gsub("^HORSE_", "")
    return (s:gsub("_", " "):lower())
end

-- Display label for a category: a curated override from data/labels.lua if set,
-- else strip the horse_/saddle_ prefix and turn underscores into spaces.
local function prettyCategory(name)
    local o = TackLabels and TackLabels.categories and TackLabels.categories[name]
    if o then return o end
    return (name:lower():gsub("^horse_", ""):gsub("^saddle_", ""):gsub("_", " "))
end

-- ---- preview horse ----
-- A clean, ride-typical model for the preview (skip gang/story/mange variants).
local function defaultModel()
    local models = dat.horse.models or {}
    for _, m in ipairs(models) do if m:find("kentuckysaddle") then return m end end
    for _, m in ipairs(models) do
        if m:find("^a_c_horse_") and not m:find("gang") and not m:find("mange") and not m:find("murfree") then return m end
    end
    return models[1]
end

-- The horse the player is currently riding, or nil. GET_MOUNT returns 0 when the
-- player isn't mounted, so a valid, existing handle means "riding a horse".
local function ridingHorse()
    local m = GetMount(PlayerPedId())   -- 0xE7E11B8DCBED1058
    if m and m ~= 0 and DoesEntityExist(m) then return m end
    return nil
end

-- Pick the horse to edit tack on: the one the player is riding if mounted,
-- otherwise spawn a clean preview horse to dress.
local function spawnPreview()
    local mount = ridingHorse()
    if mount then
        usingMount = true
        previewHorse = mount
        return previewHorse
    end
    usingMount = false
    local p = PlayerPedId()
    local c = GetEntityCoords(p)
    local h = GetEntityHeading(p)
    -- a few metres ahead, turned broadside so you see the tack on its flank
    local pos = da_util.GetGroundPositionForward(c, 5.0, h, h + 270.0)
    previewHorse = da_horse.spawn(defaultModel(), pos, { frozen = true })
    -- -- Drop it onto the ground: the ped origin is at the body centre (~1m above the
    -- -- hooves), so spawning at the player's origin z leaves it floating. Place the
    -- -- origin a body-half-height above the real ground under it.
    -- if previewHorse and DoesEntityExist(previewHorse) then
    --     local found, gz = GetGroundZFor_3dCoord(x, y, c.z + 1.0, false)
    --     if found then
    --         local mn = GetModelDimensions(GetEntityModel(previewHorse))
    --         local hoof = (mn and mn.z) or -1.0   -- distance from origin down to the hooves
    --         SetEntityCoords(previewHorse, x, y, gz - hoof, false, false, false, false)
    --     end
    -- end
    return previewHorse
end

local function despawnPreview()
    -- Only delete a horse we spawned — never the player's own mount.
    if not usingMount and previewHorse and DoesEntityExist(previewHorse) then
        da_obj.delete(previewHorse)
    end
    previewHorse = nil
    usingMount = false
end

-- ---- data views ----
-- Categories that have at least one tack item: { {name, hash, label}, ... }.
-- `name` is the raw key (used by the items callback); `label` is for display.
local function categoriesFor()
    local present = {}
    for _, it in pairs(dat.horse.items) do present[it.category] = true end
    local out = {}
    for name in pairs(present) do
        out[#out + 1] = { name = name, hash = maskHash(dat.horse.categories[name]), label = prettyCategory(name) }
    end
    table.sort(out, function(a, b) return a.label < b.label end)
    return out
end

-- Tack in a category, grouped: tint variants collapse to their base (ordered
-- variant list), singles stand alone — same flat shape da_wardrobe sends for a
-- non-two-axis category (horse tack has no style x variant axis).
local function itemsFor(catName)
    local byBase, entries = {}, {}
    for hash, it in pairs(dat.horse.items) do
        if it.category == catName then
            if it.base then
                if not byBase[it.base] then
                    local b = dat.horse.bases[it.base]
                    local variants = {}
                    for _, v in ipairs(b and b.tints or { hash }) do variants[#variants + 1] = maskHash(v) end
                    local e = { id = it.base, label = pretty(it.base), variants = variants }
                    byBase[it.base] = e
                    entries[#entries + 1] = e
                end
            else
                -- Collapse a trailing numeric suffix into one entry stepped from
                -- the bottom tint bar: _TINT_NNN tints AND the plain _NNN series
                -- tack uses (e.g. HORSE_..._BLANKET_02_NEW_000..004 -> one "blanket
                -- 02 new" with 5 steps; NEW vs USED stay separate prefixes). The
                -- group key is the name minus that trailing _NNN. Nameless (#hash)
                -- and named-without-a-number items stand alone.
                local groupKey = it.name and (it.name:match("^(.+)_TINT_%d+$") or it.name:match("^(.+)_%d+$"))
                if groupKey then
                    local e = byBase[groupKey]
                    if not e then
                        e = { id = groupKey, label = pretty(groupKey), variants = {}, _tints = {} }
                        byBase[groupKey] = e
                        entries[#entries + 1] = e
                    end
                    e._tints[#e._tints + 1] = { n = tonumber(it.name:match("_(%d+)$")) or 0, h = maskHash(hash) }
                else
                    local h = maskHash(hash)
                    entries[#entries + 1] = {
                        id = string.format("#%08X", h),
                        label = pretty(it.name) or string.format("#%08X", h),
                        variants = { h },
                    }
                end
            end
        end
    end
    for _, e in ipairs(entries) do
        if e._tints then
            table.sort(e._tints, function(a, b) return a.n < b.n end)
            for _, t in ipairs(e._tints) do e.variants[#e.variants + 1] = t.h end
            e._tints = nil
        end
    end
    table.sort(entries, function(a, b) return a.label < b.label end)
    return entries
end

-- The set of equipped tack hashes on the preview horse, masked.
local function equippedSet()
    local set = {}
    if previewHorse then
        for _, h in ipairs(da_horse.equipped(previewHorse)) do set[maskHash(h)] = true end
    end
    return set
end

local function equippedList()
    local out = {}
    for h in pairs(equippedSet()) do out[#out + 1] = h end
    return out
end

-- Category names that currently have an equipped item (UI shows a dot on them).
local function occupiedCategories()
    local set = {}
    if previewHorse then
        for _, h in ipairs(da_horse.equipped(previewHorse)) do
            local it = dat.horse.items[maskHash(h)]
            if it then set[it.category] = true end
        end
    end
    local out = {}
    for name in pairs(set) do out[#out + 1] = name end
    return out
end

local function editResult()
    return { equipped = equippedList(), cats = occupiedCategories() }
end

-- ---- mode ----
-- The UI runs as a mode (like da_wardrobe). MCP passes input through to the game
-- on MouseScrollClick so you can move the camera to view the horse while the
-- panel stays up; pressing it again returns the cursor.
local MCP_KEY = dat.keyHash["MouseScrollClick"]
local mcpOn = false

-- ---- cinematic camera ----
-- On open we engage da_dev's freecam (soft dependency) and spline the camera to a
-- framed offset of the preview horse; switching category reframes per
-- data/camera.lua. No-op without da_dev running.
local function devReady() return GetResourceState("da_dev") == "started" end

local function frameCategory(catName)
    if not devReady() or not previewHorse then return end
    local cfg = da_cam.resolve(TackCamera, catName)
    local pose = da_cam.poseFromOffset(previewHorse, cfg)
    exports.da_dev:reframeFreecam(pose, cfg.duration, cfg.smoothing)
end

local function engageCamera()
    if not devReady() then return end
    exports.da_dev:startFreecam()
    frameCategory(nil)   -- default framing until a category is picked
end

local function releaseCamera()
    if not devReady() then return end
    exports.da_dev:stopFreecam()
end

local function openPayload()
    return {
        action = "open",
        pedType = "horse",
        categories = categoriesFor(),
        equipped = equippedList(),
        cats = occupiedCategories(),
        outfits = API.listTack(),
    }
end

Citizen.CreateThread(function()
    da_mode.register({
        name = "tack",
        priority = 65,
        onActivate = function()
            open = true
            spawnPreview()
            SetCursorLocation(0.5, 0.5)
            SendNUIMessage(openPayload())
            engageCamera()
            if da_mode.isPrimary("tack") then
                SetNuiFocus(true, true)
                SetNuiFocusKeepInput(false)
            else
                SendNUIMessage({ action = "suspend" })
            end
        end,
        onDeactivate = function()
            da_mcp.deactivate()
            mcpOn = false
            open = false
            releaseCamera()
            despawnPreview()
            SendNUIMessage({ action = "close" })
            SetNuiFocus(false, false)
            SetNuiFocusKeepInput(false)
        end,
        onPrimary = function()
            if mcpOn then return end
            SetNuiFocus(true, true)
            SetNuiFocusKeepInput(false)
            SendNUIMessage({ action = "resume" })
        end,
        onLosePrimary = function()
            -- A higher-priority mode took over. NUI focus is global, so suspend the
            -- panel's JS input and hand focus to the new primary (the mode system
            -- only primary-gates game keymaps, not JS).
            da_mcp.deactivate()
            mcpOn = false
            SendNUIMessage({ action = "suspend" })
            SetNuiFocus(false, false)
            SetNuiFocusKeepInput(false)
        end,
        activateMCP = function()
            if da_mcp.active then return end
            return da_mcp.activate({
                key = MCP_KEY,
                activate = function()
                    mcpOn = true
                    SetNuiFocus(true, false)
                    SetNuiFocusKeepInput(true)
                    SendNUIMessage({ action = "mcp", active = true })
                end,
                deactivate = function()
                    da_control.waitForRelease(MCP_KEY)
                    mcpOn = false
                    SetNuiFocusKeepInput(false)
                    SendNUIMessage({ action = "mcp", active = false })
                    if da_mode.isPrimary("tack") then
                        SetNuiFocus(true, true)
                    end
                end,
            })
        end,
        keymaps = {
            {
                key = "Escape3",
                event = "justPressed",
                primary = true,
                fn = function() da_mode.deactivate("tack") end,
            },
        },
    })
end)

local function toggle()
    if da_mode.isActive("tack") then
        da_mode.deactivate("tack")
    else
        da_mode.activate("tack")
    end
end

-- ---- NUI callbacks ----
RegisterNUICallback("close", function(_, cb) da_mode.deactivate("tack"); cb({}) end)

RegisterNUICallback("activateMCP", function(_, cb) da_mode.activateMCP("tack"); cb({}) end)
RegisterNUICallback("deactivateMCP", function(_, cb) da_mcp.deactivate(); cb({}) end)

RegisterNUICallback("items", function(data, cb)
    frameCategory(data.category)
    local r = editResult()
    r.mandatory = false
    r.items = itemsFor(data.category)
    cb(r)
end)

RegisterNUICallback("equip", function(data, cb)
    if data.hash and previewHorse then da_horse.equip(data.hash, nil, previewHorse); end
    cb(editResult())
end)

RegisterNUICallback("removeCategory", function(data, cb)
    if data.categoryHash and previewHorse then da_horse.remove(data.categoryHash, previewHorse) end
    cb(editResult())
end)

RegisterNUICallback("stripAll", function(_, cb)
    -- No confirmed empty-tack preset, so strip by removing each occupied category.
    if previewHorse then
        for _, name in ipairs(occupiedCategories()) do
            local h = maskHash(dat.horse.categories[name])
            if h ~= 0 then da_horse.remove(h, previewHorse) end
        end
    end
    cb(editResult())
end)

RegisterNUICallback("saveTack", function(data, cb)
    if previewHorse then da_horse.tack.save(data.slot or "default", previewHorse) end
    cb({ outfits = API.listTack() })
end)

RegisterNUICallback("loadTack", function(data, cb)
    if previewHorse then da_horse.tack.load(data.slot or "default", previewHorse); end
    cb(editResult())
end)

RegisterNUICallback("deleteTack", function(data, cb)
    API.deleteTack(data.slot or "default")
    cb({ outfits = API.listTack() })
end)

-- ---- entry points ----
RegisterCommand("tack", function() toggle() end, false)
AddEventHandler("da_tack:toggle", toggle)

exports("toggle", toggle)
exports("isOpen", function() return open end)
