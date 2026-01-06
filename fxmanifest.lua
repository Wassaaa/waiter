fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'waiter'
description 'Waiter Job - Client-side restaurant management system'
author 'Wassaaa'
version '1.0.0'

shared_scripts {
  '@ox_lib/init.lua',
}

files {
  'config/client.lua',
  'config/shared.lua',
}

server_scripts {
  'server/main.lua',
}

client_scripts {
  'client/state.lua',
  'client/tray.lua',
  'client/customers.lua',
  'client/furniture.lua',
  'client/main.lua',
}

dependencies {
  'ox_lib',
  'ox_target',
  'qbx_core',
}
