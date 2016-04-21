--- Allows for making queries against the League of Legends Summoner API
--
-- By first creating an api object and creating a new summoner object from it
-- you can then make queries against the League of Legends Summoner API.
--
-- @module lol.summoner

local api = require('lol.api')
local utils = require('pl.utils')

--- This class encapsulates manipulating the League of Legends Summoner API
-- @type summoner
local _summoner = {}
_summoner.__index = _summoner
setmetatable(_summoner, {
    __call = function(_,apiObj)
        return _summoner.new(apiObj)
    end})

--- Create a new summoner object
-- @param api the @{api} object that communicates with the League of Legends server
-- @return a new summoner object
-- @function summoner:summoner
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

local function cacheSummonerName(cache, name, id)
    -- Currently no expiration time for name -> id mapping since I
    -- assume a name change doesn't allow someone to take the old name.
    -- If that isn't true I need to allow it to expire as well. 
    name = _summoner.standardizeSummonerName(name)
    cache:set(cacheKeyForName(name),id)

    return name
end

--- Given a Summoner name, put it into the League of Legends API standardized format
-- @tparam string summonerName the Summoner name to standardize
-- @return a Summoner name in the League of Legends API standardized format
-- @function summoner.standardizeSummonerName
function _summoner.standardizeSummonerName(summonerName)
    return string.lower(string.gsub(summonerName, '%s+', ''))
end

--- Get a Summoner from the League of Legends API given a Summoner name
-- @tparam string name the Summoner name of the Summoner to retreive
-- @tparam table opts a table with optional parameters:
-- @tparam long opts.expire how long in seconds to cache a response (defaults to 24 hours, _i.e. 24\*60\*60_)
-- @tparam function opts.callback a callback which receives the response from the API (data, code, headers)
--   _NOTE_: Since you may only retreive 40 summoners at a time the callback may be called multiple times from a single call to summoner:getByName
-- @function summoner:getByName
function _summoner:getByName(name, opts)
    return self:getByNames({name}, opts)
end

--- Get multiple Summoners from the League of Legends API given their Summoner names
-- @tparam table names an array-like table with the list of Summoner names to retreive
-- @tparam table opts a table with optional parameters:
-- @tparam long opts.expire how long in seconds to cache a response (defaults to 24hrs, i.e. 24*60*60)
-- @tparam function opts.callback a callback which receives the response from the API (data, code, headers)
--   _NOTE_: Since you may only retreive 40 summoners at a time the callback may be called multiple times from a single call to summoner:getByNames
-- @function summoner:getByNames
function _summoner:getByNames(names, opts)
    opts = opts or {}

    local cache = self.api.cache
    local expire = opts.expire or 24*60*60
    local onResponse = function(res, code, headers)
        if code and code == 200 then
            for name,summoner in pairs(res) do
                cacheSummonerName(cache, name, summoner.id)
                cache:set(cacheKeyForId(summoner.id),summoner,expire)
            end
        end

        if opts.callback then
            opts.callback(res, code, headers)
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

    if cachedCount > 0 and opts.callback then
        opts.callback(cachedSummoners)
    end
end

--- Get a Summoner, their runes, names, or masteries from the League of Legends API given their Summoner id
-- @tparam long id Summoner id of the Summoner who's data to retreive
-- @tparam table opts a table with optional parameters:
-- @tparam string filter denotes what type of information to retreive, valid values:
--   *'name'
--   * 'masteries'
--   * 'runes'
-- @tparam long opts.expire how long in seconds to cache a response (defaults to 24hrs, i.e. 24*60*60)
-- @tparam function opts.callback a callback which receives the response from the API (data, code, headers)
--   _NOTE_: Since you may only retreive 40 summoners at a time the callback may be called multiple times from a single call to summoner:getById
-- @function summoner:getById
function _summoner:getById(id, opts)
    self:getByIds({id}, opts)
end

--- Get multiple Summoners, their runes, names, or masteries from the League of Legends API given their Summoner ids
-- @tparam table ids an array-like table with the list of Summoner ids to retreive
-- @tparam table opts a table with optional parameters:
-- @tparam string filter denotes what type of information to retreive, valid values:
--   * 'name'
--   * 'masteries'
--   * 'runes'
-- @tparam long opts.expire how long in seconds to cache a response (defaults to 24hrs, i.e. 24*60*60)
-- @tparam function opts.callback a callback which receives the response from the API (data, code, headers)
--   _NOTE_: Since you may only retreive 40 summoners at a time the callback may be called multiple times from a single call to summoner:getIds
-- @function summoner:getByIds
function _summoner:getByIds(ids, opts)
    opts = opts or {}

    local cache = self.api.cache
    local expire = opts.expire or 24*60*60
    local onResponse = function(res, code, headers)
        local data = {}
        if code and code == 200 then
            for _,summoner in pairs(res) do
                local name = cacheSummonerName(cache, summoner.name, summoner.id)
                cache:set(cacheKeyForId(summoner.id),summoner,expire)

                data[name] = summoner
            end
        end

        if opts.callback then
            opts.callback(data, code, headers)
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
            if code and code == 200 then
                for idstr,name in pairs(res) do
                    local id = tonumber(idstr)
                    cacheSummonerName(cache, name, id)

                    data[id] = name
                end
            end

            if opts.callback then
                opts.callback(data, code, headers)
            end
        end,
        masteries=function(res, code, headers)
            local data = {}
            if code and code == 200 then
                for idstr,val in pairs(res) do
                    local id = tonumber(idstr)
                    cache:set(cacheKeyForMasteries(id),val.pages,expire)

                    data[id] = val.pages
                end
            end

            if opts.callback then
                opts.callback(data, code, headers)
            end
        end,
        runes=function(res, code, headers)
            local data = {}
            if code and code == 200 then
                for idstr,val in pairs(res) do
                    local id = tonumber(idstr)
                    cache:set(cacheKeyForRunes(id),val.pages,expire)

                    data[id] = val.pages
                end
            end

            if opts.callback then
                opts.callback(data, code, headers)
            end
        end
    }

    if opts.filter then
        utils.assert_arg(2,opts.filter,'string',function() return onFilterResponse[opts.filter] end,'not a valid api object')
    end

    local cachedCount = 0
    local cachedData = {}
    local maxIdsPerQuery = 40
    local url = {
        params={version=self.version,filter=opts.filter and '/'..opts.filter or ''},
        path='/api/lol/${region}/v${version}/summoner/${summonerIds}${filter}',
    }

    for index,summonerId in ipairs(ids) do
        local cacheKeyFn = opts.filter and cacheKeyForFilter[opts.filter] or cacheKeyForId
        local data = cache:get(cacheKeyFn(summonerId))

        if data then
            local key = opts.filter and summonerId or self.standardizeSummonerName(data.name)
            cachedData[key] = opts.filter and cacheKeyFn == cacheKeyForId and data.name or data
            cachedCount = cachedCount + 1
        else
            local idString = url.params.summonerIds
            url.params.summonerIds = idString and idString..','..summonerId or summonerId

            if (index - cachedCount) % maxIdsPerQuery == 0 then
                self.api:get(url, onFilterResponse[opts.filter] or onResponse)
                url.params.summonerIds = nil
            end
        end
    end

    if url.params.summonerIds then
        self.api:get(url, onFilterResponse[opts.filter] or onResponse)
    end

    if cachedCount > 0 and opts.callback then
        opts.callback(cachedData)
    end
end

return _summoner
