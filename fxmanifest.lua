fx_version 'cerulean'
game 'gta5'
author 'Antigravity'
description 'Void Prison - Dynamic Jail Script with MDT, Jobs, Breakouts and Tablet UI'
version '1.0.0'

dependencies {
    'ox_lib',
}

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

client_scripts {
    'client/cl_main.lua',
    'client/cl_jobs.lua',
    'client/cl_breakout.lua',
    'client/cl_tablet.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/sv_main.lua',
    'server/sv_jobs.lua'
}

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/style.css',
    'web/script.js'
}
