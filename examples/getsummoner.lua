local lol = require('lol')
local api = lol.api('../keys/devel', 'na', '../cache')
local summoner = lol.summoner(api)

summoner:getByName('Calm the Violent', function(res, code)
    print(res)
end)
