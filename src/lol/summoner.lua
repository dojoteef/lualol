--- Allows for making queries against the League of Legends Summoner API
--
-- By first creating an api object and creating a new summoner object from it
-- you can then make queries against the League of Legends Summoner API.
--
-- @module lol.summoner

local api = require('lol.api')
local utils = require('pl.utils')

local _summoner = {}
_summoner.__index = _summoner
setmetatable(_summoner, {
    __call = function(_,apiObj)
        return _summoner.new(apiObj)
    end})

--- Create a new summoner object
-- @param apiObj - the api object that communicates with the League of Legends server
-- @return a new summoner object
-- @function summoner
function _summoner.new(apiObj)
    utils.assert_arg(1,apiObj,'table',api.isvalid,'not a valid api object')

    local obj = {}
    obj.api = apiObj
    obj.version = '1.4'

    return setmetatable(obj, _summoner)
end

local function cacheKeyForId(summonerId)
    return {api='summoner',summonerId=summonerId}
end

local function cacheKeyForName(summonerName)
    return {api='summoner',summonerName=summonerName}
end

--- Given a Summoner name, put it into the League of Legends API standardized format
-- @param summonerName - the Summoner name to standardize
-- @return a Summoner name in the League of Legends API standardized format
function _summoner.standardizeSummonerName(summonerName)
    return string.lower(string.gsub(summonerName, '%s+', ''))
end

--- Get a Summoner from the League of Legends API given a Summoner name
-- @param name - the Summoner name of the Summoner to retreive
-- @param callback - a callback which receives the response from the API
function _summoner:getByName(name, callback)
    return self:getByNames({name}, callback)
end

--- Get multiple Summoners from the League of Legends API given their Summoner names
-- @param names - an array-like table with the list of Summoner names to retreive
-- @param callback - a callback which receives the response from the API
--   * NOTE: Since you may only retreive 40 summoners at a time the callback may
--   * be called multiple times from a single call to summoner:getByNames
function _summoner:getByNames(names, callback)
    local cache = self.api.cache
    local onResponse = function(res, code)
        for name,summoner in pairs(res) do
            cache:set(cacheKeyForName(name),summoner.id)
            cache:set(cacheKeyForId(summoner.id),summoner,24*60*60)
        end

        if callback then
            callback(res, code)
        end
    end

    local cachedCount = 0
    local cachedSummoners = {}
    local maxNamesPerQuery = 40
    local pathParams = {version=self.version}
    local path = '/api/lol/${region}/v${version}/summoner/by-name/${summonerNames}'

    for index,name in ipairs(names) do
        local summonerName = self.standardizeSummonerName(name)
        local summonerId = cache:get(cacheKeyForName(summonerName))

        local summoner
        if summonerId then
            summoner = cache:get(cacheKeyForId(summonerId))
        end

        if summoner then
            cachedCount = cachedCount + 1
            cachedSummoners[summonerName] = summoner
        else
            local nameString = pathParams.summonerNames
            pathParams.summonerNames = nameString and nameString..','..summonerName or summonerName

            if (index - cachedCount) % maxNamesPerQuery == 0 then
                self.api:get(path, pathParams, {callback=onResponse})
                pathParams.summonerNames = nil
            end
        end
    end

    if pathParams.summonerNames then
        self.api:get(path, pathParams, {callback=onResponse})
    end

    if cachedCount and callback then
        callback(cachedSummoners)
    end
end

return _summoner
