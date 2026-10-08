fx_version 'cerulean'
game 'gta5'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

name 'tr_example'
author 'TR Scripts'
description 'Describe what this resource does'
version '0.1.0'

shared_scripts {
    '@tr_core/init.lua',
    'shared/config.lua',
}

server_script 'server/main.lua'
client_script 'client/main.lua'

files {
    'locales/*.json',
}

dependencies {
    'tr_core',
}
