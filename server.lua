print('^2[Server] Practice Script Started!^7')

-- A server-side command: /ping
RegisterCommand('ping', function(source, args)
    local src = source -- The ID of the player who typed it
    print('Player ' .. src .. ' used the ping command.')
end, false)
