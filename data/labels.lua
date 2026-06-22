-- Display labels for the tack editor — curate nicer names here as you go.
--   categories: keyed by the raw category name (see dat.horse.categories)
--   components: keyed by component hash (for the hash-only items especially)
-- Anything not listed falls back to a generic prettifier (categories strip the
-- horse_/saddle_ prefix and turn underscores into spaces; components use the
-- existing name prettifier or "#HASH"). Components are not wired yet — fill the
-- table now and we'll hook it up when you're ready.
TackLabels = {
    categories = {
        -- ["horse_saddles"]    = "saddles",
        -- ["HORSE_SADDLEBAGS"] = "saddlebags",
        -- ["saddle_stirrups"]  = "stirrups",
    },
    components = {
        -- [0x9FD99D7D] = "Old Bedroll",
    },
}
