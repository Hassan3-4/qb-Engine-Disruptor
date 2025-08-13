fx_version 'cerulean'

game 'gta5'

name 'Vehicle-stop'
author 'AI Agent'
description 'Police engine disruptor (qb-core)'
version '1.0.0'

lua54 'yes'

shared_script 'shared/config.lua'

client_scripts {
    'client/ui.lua',
    'client/safezones.lua',
    'client/hooks.lua',
    'client/target.lua',
    'client/officer.lua'
}

server_scripts {
    'server/main.lua'
}

files {
    'assets/engine_disruptor.png'
}
