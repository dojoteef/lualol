--- Allows for making queries against the League of Legends Game API
--
-- By first creating an api object and creating a new game object from it
-- you can then make queries against the League of Legends Summoner API.
--
-- @module lol.game

local api = require('lol.api')
local utils = require('pl.utils')

local _game = {}
_game.__index = _game
setmetatable(_game, {
    __call = function(_,apiObj)
        return _game.new(apiObj)
    end})

--- Create a new game object
-- @param apiObj - the api object that communicates with the League of Legends server
-- @return a new game object
-- @function game
function _game.new(apiObj)
    utils.assert_arg(1,apiObj,'table',api.isvalid,'not a valid api object')

    local obj = {}
    obj.api = apiObj
    obj.version = '1.3'

    return setmetatable(obj, _game)
end

--- Get a list of recent games by Summoner id
-- @param summonerId - the id of the Summoner whose recent games you wish to retreive
-- @param callback - a callback which receives the response from the API
function _game:getBySummonerId(summonerId, callback)
    local cache = self.api.cache
    local cacheKey = {api='game',summonerId=summonerId}
    local onResponse = function(res, code)
        cache:set(cacheKey,res,5*60*60)

        if callback then
            callback(res, code)
        end
    end

    local game = cache:get(cacheKey)
    if game and callback then
        callback(game)
    else
        local path = '/api/lol/${region}/v${version}/game/by-summoner/${summonerId}/recent'
        self.api:get(path, {version=self.version,summonerId=summonerId}, {callback=onResponse})
    end
end

return _game
