fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'waiter'
description 'Waiter Job - Client-side restaurant management system'
author 'Wassaaa'
version '1.0.0'

shared_scripts {
  '@ox_lib/init.lua',
  'shared/utils.lua',
}

server_scripts {
  'server/tray.lua',
  'server/main.lua',
  'server/furniture.lua',
  'server/customers.lua',
}

client_scripts {
  'client/state.lua',
  'client/main.lua',
  'client/tray_statebag.lua',
  'client/customers.lua',
  'client/furniture.lua',
  'client/tray_minigame.lua',
}

files {
  'config/client.lua',
  'config/shared.lua',
  'client/lib/controls.lua',
  'client/lib/raycast.lua',
  'client/lib/dragdrop.lua',
  'client/lib/tray.lua',
}

dependencies {
  'ox_lib',
  'ox_target',
  'qbx_core',
}
