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

local function cacheKeyForName(summonerName)
    return {api='summoner',summonerName=summonerName}
end

local function cacheKeyForId(summonerId)
    return {api='summoner',summonerId=summonerId}
end

local function cacheKeyForMasteries(summonerId)
    return {api='summoner',data='masteries',summonerId=summonerId}
end

local function cacheKeyForRunes(summonerId)
    return {api='summoner',data='runes',summonerId=summonerId}
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
    local onResponse = function(res, code, headers)
        for name,summoner in pairs(res) do
            cache:set(cacheKeyForName(name),summoner.id)
            cache:set(cacheKeyForId(summoner.id),summoner,24*60*60)
        end

        if callback then
            callback(res, code, headers)
        end
    end

    local cachedCount = 0
    local cachedSummoners = {}
    local maxNamesPerQuery = 40
    local url = {
        params={version=self.version},
        path='/api/lol/${region}/v${version}/summoner/by-name/${summonerNames}',
    }

    for index,name in ipairs(names) do
        local summonerName = self.standardizeSummonerName(name)
        local summonerId = cache:get(cacheKeyForName(summonerName))

        local summoner
        if summonerId then
            summoner = cache:get(cacheKeyForId(summonerId))
        end

        if summoner then
            cachedSummoners[summonerName] = summoner
            cachedCount = cachedCount + 1
        else
            local nameString = url.params.summonerNames
            url.params.summonerNames = nameString and nameString..','..summonerName or summonerName

            if (index - cachedCount) % maxNamesPerQuery == 0 then
                self.api:get(url, onResponse)
                url.params.summonerNames = nil
            end
        end
    end

    if url.params.summonerNames then
        self.api:get(url, onResponse)
    end

    if cachedCount > 0 and callback then
        callback(cachedSummoners)
    end
end

--- Get multiple Summoners from the League of Legends API given their Summoner ids
-- @param ids - an array-like table with the list of Summoner ids to retreive
-- @param filter - optional parameter denoting what type of information to retreive
--   * valid values: 'name', 'masteries', 'runes'
-- @param callback - a callback which receives the response from the API
--   * NOTE: Since you may only retreive 40 summoners at a time the callback may
--   * be called multiple times from a single call to summoner:getByIds
function _summoner:getByIds(ids, filter, callback)
    local cache = self.api.cache
    local onResponse = function(res, code, headers)
        local data = {}
        for _,summoner in pairs(res) do
            local summonerName = self.standardizeSummonerName(summoner.name)
            cache:set(cacheKeyForName(summonerName),summoner.id)
            cache:set(cacheKeyForId(summoner.id),summoner,24*60*60)

            data[summonerName] = summoner
        end

        if callback then
            callback(data, code, headers)
        end
    end

    local cacheKeyForFilter = {
        name=cacheKeyForId,
        masteries=cacheKeyForMasteries,
        runes=cacheKeyForRunes
    }

    local onFilterResponse = {
        name=function(res, code, headers)
            local data = {}
            for idstr,name in pairs(res) do
                local id = tonumber(idstr)
                local summonerName = self.standardizeSummonerName(name)
                cache:set(cacheKeyForName(summonerName),id)

                data[id] = name
            end

            if callback then
                callback(data, code, headers)
            end
        end,
        masteries=function(res, code, headers)
            local data = {}
            for idstr,val in pairs(res) do
                local id = tonumber(idstr)
                cache:set(cacheKeyForMasteries(id),val.pages,24*60*60)

                data[id] = val.pages
            end

            if callback then
                callback(data, code, headers)
            end
        end,
        runes=function(res, code, headers)
            local data = {}
            for idstr,val in pairs(res) do
                local id = tonumber(idstr)
                cache:set(cacheKeyForRunes(id),val.pages,24*60*60)

                data[id] = val.pages
            end

            if callback then
                callback(data, code, headers)
            end
        end
    }

    if filter then
        utils.assert_arg(2,filter,'string',function() return onFilterResponse[filter] end,'not a valid api object')
    end

    local cachedCount = 0
    local cachedData = {}
    local maxNamesPerQuery = 40
    local url = {
        params={version=self.version,filter=filter and '/'..filter or ''},
        path='/api/lol/${region}/v${version}/summoner/${summonerIds}${filter}',
    }

    for index,summonerId in ipairs(ids) do
        local cacheKeyFn = filter and cacheKeyForFilter[filter] or cacheKeyForId
        local data = cache:get(cacheKeyFn(summonerId))

        if data then
            local key = filter and summonerId or self.standardizeSummonerName(data.name)
            cachedData[key] = filter and cacheKeyFn == cacheKeyForId and data.name or data
            cachedCount = cachedCount + 1
        else
            local idString = url.params.summonerIds
            url.params.summonerIds = idString and idString..','..summonerId or summonerId

            if (index - cachedCount) % maxNamesPerQuery == 0 then
                self.api:get(url, onFilterResponse[filter] or onResponse)
                url.params.summonerIds = nil
            end
        end
    end

    if url.params.summonerIds then
        self.api:get(url, onFilterResponse[filter] or onResponse)
    end

    if cachedCount > 0 and callback then
        callback(cachedData)
    end
end

return _summoner
