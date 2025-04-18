fx_version 'cerulean'
game 'gta5'

author 'Your Name'
description 'Black Market Courier System'
version '1.0.0'

shared_scripts {
    '@qb-core/shared/locale.lua',
    'config/config.lua',
    'config/locales.lua'
}

client_scripts {
    'client/main.lua',
    'client/burner_phone.lua',
    'client/courier_jobs.lua',
    'client/police_awareness.lua',
    'client/utils.lua'
}

server_scripts {
    'server/main.lua',
    'server/contracts.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/script.js',
    'html/style.css',
    'html/reset.css',
    'html/assets/**/*'
} 