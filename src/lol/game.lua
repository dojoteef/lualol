--- Allows for making queries against the League of Legends Game API
--
-- By first creating an api object and creating a new game object from it
-- you can then make queries against the League of Legends Game API.
--
-- @module lol.game

local api = require('lol.api')
local utils = require('pl.utils')

--- This class encapsulates manipulating the League of Legends Game API
-- @type game
local _game = {}
_game.__index = _game
setmetatable(_game, {
    __call = function(_,apiObj)
        return _game.new(apiObj)
    end})

--- Create a new game object
-- @param api the @{api} object that communicates with the League of Legends server
-- @return a new game object
-- @function game:game
function _game.new(apiObj)
    utils.assert_arg(1,apiObj,'table',api.isvalid,'not a valid api object')

    local obj = {}
    obj.api = apiObj
    obj.version = '1.3'

    return setmetatable(obj, _game)
end

--- Get a list of recent games by Summoner id
-- @tparam long summonerId the id of the Summoner whose recent games you wish to retreive
-- @tparam table opts a table with optional parameters:
-- @tparam long opts.expire how long in seconds to cache a response (defaults to 5 hours, _i.e. 5\*60\*60_)
-- @tparam function opts.callback a callback which receives the response from the API (data, code, headers)
-- @function game:getBySummonerId
function _game:getBySummonerId(summonerId, opts)
    opts = opts or {}

    local cache = self.api.cache
    local cacheKey = {api='game',summonerId=summonerId}
    local expire = opts.expire or 5*60*60
    local onResponse = function(res, code, headers)
        if code and code == 200 then
            cache:set(cacheKey,res,expire)
        end

        if opts.callback then
            opts.callback(res, code, headers)
        end
    end

    local game = cache:get(cacheKey)
    if game and opts.callback then
        opts.callback(game)
    else
        local url = {
            path='/api/lol/${region}/v${version}/game/by-summoner/${summonerId}/recent',
            params={version=self.version,summonerId=summonerId},
        }
        self.api:get(url, onResponse)
    end
end

return _game
