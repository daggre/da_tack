-- Camera framing for the tack editor, consumed by da_cam.resolve / poseFromOffset.
-- Offsets are in the HORSE's local frame: x = right (side), y = forward (nose),
-- z = up. The horse entity origin is at the body CENTER (confirmed via
-- GetModelDimensions: spans z -1.0 hooves .. +1.1 top, y ±1.9 nose..tail), so
-- z=0 is mid-barrel, ~+0.4 the saddle/back, ~-0.6 the lower legs. `default` is a
-- side shot of the saddle area; `categories` reframe per tack slot.
--
-- `anim` / `light` are accepted by the schema but NOT applied yet (camera-only
-- phase) — reserved so per-category mood can be layered in later.
TackCamera = {
    default = {
        offset    = { x = 3.2, y = 0.0, z = 0.7 },   -- broadside, saddle in frame
        look      = { x = 0.0, y = 0.0, z = 0.3 },
        fov       = 40.0,
        duration  = 550,
        smoothing = 0,
    },
    categories = {
        -- saddle & on-back gear: broadside
        horse_saddles    = { offset = { 3.0, 0.0, 0.7 },  look = { 0.0, 0.0, 0.3 },  fov = 38.0 },
        horse_blankets   = { offset = { 3.0, 0.0, 0.7 },  look = { 0.0, 0.0, 0.35 }, fov = 38.0 },
        horse_bedrolls   = { offset = { 3.0, -0.3, 0.7 }, look = { 0.0, -0.2, 0.35 }, fov = 38.0 },
        HORSE_SADDLEBAGS = { offset = { 3.0, -0.4, 0.5 }, look = { 0.0, -0.3, 0.2 },  fov = 36.0 },
        horse_accessories = { offset = { 3.0, 0.0, 0.6 }, look = { 0.0, 0.0, 0.3 },  fov = 38.0 },
        saddle_lanterns  = { offset = { 2.8, -0.2, 0.6 }, look = { 0.0, -0.1, 0.3 }, fov = 34.0 },
        -- small saddle parts: tighter
        saddle_horns     = { offset = { 2.0, 0.5, 0.7 },  look = { 0.0, 0.3, 0.45 }, fov = 26.0 },
        saddle_stirrups  = { offset = { 2.4, 0.0, -0.05 }, look = { 0.0, 0.0, -0.3 }, fov = 32.0 },
        -- head: framed from the front
        horse_bridles    = { offset = { 0.6, 3.2, 0.55 }, look = { 0.0, 1.3, 0.5 },  fov = 28.0 },
        horse_manes      = { offset = { 1.4, 1.6, 0.7 },  look = { 0.0, 0.9, 0.5 },  fov = 30.0 },
        horse_mustache   = { offset = { 0.5, 3.0, 0.45 }, look = { 0.0, 1.3, 0.4 },  fov = 22.0 },
        -- tail: framed from behind
        HORSE_TAILS      = { offset = { 1.0, -3.0, 0.2 }, look = { 0.0, -1.3, -0.1 }, fov = 32.0 },
        -- shoes: low side
        horse_shoes      = { offset = { 2.2, 0.8, -0.6 }, look = { 0.0, 0.6, -0.9 },  fov = 30.0 },
    },
}
