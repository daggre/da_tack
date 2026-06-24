fx_version 'cerulean'
games {'rdr3'}
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

author 'daggre_actual'
description 'Low-profile in-game UI for building horse-tack loadouts (imports da_horse)'
version '0.1'
lua54 'yes'

shared_scripts {
    '@da_log/log_sh.lua',
    '@da_lib/features/kvp/kvp_sh.lua',
}

client_scripts {
    -- the horse lib this UI drives, plus its data and the API stack tack
    -- save/load routes through (Default adapter -> KVP)
    '@da_lib/features/api/api_sh.lua',
    '@da_lib/features/api/default/default_cl.lua',
    '@da_lib/data/horse.lua',
    '@da_lib/features/object/object_cl.lua',
    '@da_lib/features/horse/horse_cl.lua',
    '@da_lib/features/util/util_cl.lua',

    -- mode + MCP (the UI runs as a mode, like da_wardrobe)
    '@da_lib/data/key.lua',
    '@da_lib/features/control/control_cl.lua',
    '@da_lib/features/mode/mode_cl.lua',
    '@da_lib/features/mode/mcp_cl.lua',

    -- camera lib + per-category framing config (cinematic entry / reframe)
    '@da_lib/features/camera/camera_cl.lua',
    'data/camera.lua',
    'data/labels.lua',

    'client/tack_cl.lua',
}

ui_page 'ui/index.html'

files {
    'ui/index.html',
    'ui/assets/css/base.css',
    'ui/assets/fonts/LiterationMonoNerd.ttf',
    'ui/style.css',
    'ui/script.js',
}

dependencies {
    'da_lib',
}
