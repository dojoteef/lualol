--- Allows for making queries against the League of Legends Matchlist API
--
-- By first creating an api object and creating a new matchlist object from it
-- you can then make queries against the League of Legends Summoner API.
--
-- @module lol.matchlist

local api = require('lol.api')
local utils = require('pl.utils')

local _matchlist = {}
_matchlist.__index = _matchlist
setmetatable(_matchlist, {
    __call = function(_,apiObj)
        return _matchlist.new(apiObj)
    end})

--- Create a new matchlist object
-- @param apiObj - the api object that communicates with the League of Legends server
-- @return a new matchlist object
-- @function matchlist
function _matchlist.new(apiObj)
    utils.assert_arg(1,apiObj,'table',api.isvalid,'not a valid api object')

    local obj = {}
    obj.api = apiObj
    obj.version = '2.2'

    return setmetatable(obj, _matchlist)
end

local function validateFilters(filters)
    -- TODO
    return filters
end

--- Get a list of matches by Summoner id that statisfy the passed in filters
-- @param summonerId - the id of the Summoner whose matchlist you wish to retreive
-- @param filters - a table specifying how to filter the matchlist
--   *  NOTE: this isn't functional yet, you must pass in an empty table for now
-- @param callback - a callback which receives the response from the API
function _matchlist:getBySummonerId(summonerId, filters, callback)
    utils.assert_arg(2,filters,'table',validateFilters,'invalid filters specified')

    local cache = self.api.cache
    local cacheKey = {api='matchlist',summonerId=summonerId,filters=filters}
    local onResponse = function(res, code)
        cache:set(cacheKey,res,60*60)

        if callback then
            callback(res, code)
        end
    end

    local matchlist = cache:get(cacheKey)
    if matchlist and callback then
        callback(matchlist)
    else
        local path = '/api/lol/${region}/v${version}/matchlist/by-summoner/${summonerId}'
        self.api:get(path, {version=self.version,summonerId=summonerId}, {callback=onResponse})
    end
end

return _matchlist
