--- Allows for making queries against the League of Legends League API
--
-- By first creating an api object and creating a new league object from it
-- you can then make queries against the League of Legends Summoner API.
--
-- @module lol.league

local api = require('lol.api')
local plutils = require('pl.utils')
local pltablex = require('pl.tablex')

--- This class encapsulates manipulating the League of Legends League API
-- @type league
local _league = {
    --- The ranked queues available to filter on
    RankedQueues = {
        RANKED_SOLO_5x5='summoner', -- Ranked Solo 5x5
        RANKED_TEAM_3x3='team', -- Ranked Team 3x3
        RANKED_TEAM_5x5='team', -- Ranked Team 5x5
    },
    --- The leagues to query
    Leagues = {
        master='MASTER', -- Master League
        challenger='CHALLENGER', -- Challenger League
    },
    --- The id types for querying
    IdTypes = {
        summoner=true, -- Summoner Id
        team=true, -- Team Id
    }
}
_league.__index = _league
setmetatable(_league, {
    __call = function(_,apiObj)
        return _league.new(apiObj)
    end})

--- Create a new league object
-- @param api the @{api} object that communicates with the League of Legends server
-- @return a new league object
-- @function league:league
function _league.new(apiObj)
    plutils.assert_arg(1,apiObj,'table',api.isvalid,'not a valid api object')

    local obj = {}
    obj.api = apiObj
    obj.version = '2.5'

    return setmetatable(obj, _league)
end

local function cacheKeyForId(id, idType)
    return (idType == 'summoner' and {api='league',summonerId=tostring(id)}) or (idType == 'team' and {api='league',teamId=tostring(id)})
end

local function cacheKeyForLeague(queue, tier)
    return {api='league',queue=queue,tier=tier}
end

--- Get the master league
-- @tparam string queue a string from @{RankedQueues|ranked queues} denoting the queue to query for
-- @tparam table opts a table of optional parameters
--
--   * `expire:` how long in seconds to cache a response (defaults to 1 week, _i.e. 7\*24\*60\*60_)
--   * `callback:` a callback which receives the response from the API (data, code, headers)
--
-- 
-- @function league:getMasterLeague
function _league:getMasterLeague(queue, opts)
    return self:getLeague('master', queue, opts)
end

--- Get the challenger league
-- @tparam string queue a string from @{RankedQueues|ranked queues} denoting the queue to query for
-- @tparam table opts a table of optional parameters
--
--   * `expire:` how long in seconds to cache a response (defaults to 1 week, _i.e. 7\*24\*60\*60_)
--   * `callback:` a callback which receives the response from the API (data, code, headers)
--
-- 
-- @function league:getChallengerLeague
function _league:getChallengerLeague(queue, opts)
    return self:getLeague('challenger', queue, opts)
end

--- Get the specified league
-- @tparam string league a string from @{Leagues|leagues} denoting the type of league to get
-- @tparam string queue a string from @{RankedQueues|ranked queues} denoting the queue to query for
-- @tparam table opts a table of optional parameters
--
--   * `expire:` how long in seconds to cache a response (defaults to 1 week, _i.e. 7\*24\*60\*60_)
--   * `callback:` a callback which receives the response from the API (data, code, headers)
--
-- 
-- @function league:getLeague
function _league:getLeague(league, queue, opts)
    opts = opts or {}

    plutils.assert_arg(1,league,'string',function() return self.Leagues[league] end,'not a valid league')
    plutils.assert_arg(2,queue,'string',function() return self.RankedQueues[queue] end,'not a valid queue')
    plutils.assert_arg(3,opts,'table')

    local cache = self.api.cache
    local expire = opts.expire or 7*24*60*60
    local onResponse = function(res, code, headers)
        if code and code == 200 then
            local leagueCacheKey = cacheKeyForLeague(res.queue, res.tier)
            cache:set(leagueCacheKey,res,expire)

            local idtype = _league.RankedQueues[queue]
            if res.entries then
                for _,entry in ipairs(res.entries) do
                    -- if a cache entry already exists for this summoner or team, simply update the
                    -- league entry for the particular league rather than overwriting the entire
                    -- list of entries
                    local cacheKey = cacheKeyForId(entry.playerOrTeamId, idtype)

                    -- find the existing cached entry
                    local cacheData = cache:get(cacheKey) or {}
                    local entryIndex = #cacheData+1
                    for index,cachedEntry in ipairs(cacheData) do
                        if cachedEntry.queue == res.queue and cachedEntry.tier == res.tier then
                            entryIndex = index
                            break
                        end
                    end

                    -- make a new entry including the queue and tier along with
                    -- the key/value pairs of the entry
                    local cacheEntry = pltablex.deepcopy(entry)
                    cacheEntry.queue = res.queue
                    cacheEntry.tier = res.tier

                    cacheData[entryIndex] = cacheEntry
                    cache:set(cacheKey,cacheData,expire)
                end
            end
        end

        if opts.callback then
            opts.callback(res, code, headers)
        end
    end

    local url = {
        path='/api/lol/${region}/v${version}/league/${league}',
        params={version=self.version,league=league},
        query={type=queue}
    }

    local cachedLeague = cache:get(cacheKeyForLeague(queue, self.Leagues[league]))
    if cachedLeague then
        if opts.callback then
            opts.callback(cachedLeague)
        end
    else
        self.api:get(url, onResponse)
    end
end

--- Get a list of leagues by Summoner or Team ids
-- @tparam table ids an array-like table with the list of Summoner or Team ids whose leagues you wish to retreive
-- @tparam string idtype a string which is either 'summoner' or 'team' denoting the type of ids passed in
-- @tparam table opts a table of optional parameters
--
--   * `expire:` how long in seconds to cache a response (defaults to 1 week, _i.e. 7\*24\*60\*60_)
--   * `callback:` a callback which receives the response from the API (data, code, headers)
--
-- 
-- @function league:getByIds
function _league:getByIds(ids, idtype, opts)
    opts = opts or {}

    plutils.assert_arg(1,ids,'table')
    plutils.assert_arg(2,idtype,'string',function() return self.IdTypes[idtype] end,'not a valid id type')
    plutils.assert_arg(3,opts,'table')

    local cachedLeagues = {}
    local cache = self.api.cache
    local expire = opts.expire or 7*24*60*60
    local onResponse = function(res, code, headers)
        local data = {}
        if code and code == 200 then
            for _,leagues in pairs(res) do
                for _,league in ipairs(leagues) do
                    -- clear out any participant id from the league as it's specific to this request,
                    -- rather than to the league itself
                    league.participantId = nil

                    -- if we had a cached league we looked up from a summoner or team id, clear it
                    -- as we have just gotten updated data for the league and we only want
                    -- to return a league once
                    local leagueCacheKey = cacheKeyForLeague(league.queue, league.tier)
                    cachedLeagues[leagueCacheKey] = nil

                    cache:set(leagueCacheKey,league,expire)
                    data[leagueCacheKey] = league

                    for _,entry in ipairs(league.entries) do
                        -- if a cache entry already exists for this summoner or team, simply update the
                        -- league entry for the particular league rather than overwriting the entire
                        -- list of entries
                        local cacheKey = cacheKeyForId(entry.playerOrTeamId, idtype)

                        -- find the existing cached entry
                        local cacheData = cache:get(cacheKey) or {}
                        local entryIndex = #cacheData+1
                        for index,cachedEntry in ipairs(cacheData) do
                            if cachedEntry.queue == league.queue and cachedEntry.tier == league.tier then
                                entryIndex = index
                                break
                            end
                        end

                        -- make a new entry including the queue and tier along with
                        -- the key/value pairs of the entry
                        local cacheEntry = pltablex.deepcopy(entry)
                        cacheEntry.queue = league.queue
                        cacheEntry.tier = league.tier

                        cacheData[entryIndex] = cacheEntry
                        cache:set(cacheKey,cacheData,expire)
                    end
                end
            end
        end

        if opts.callback then
            opts.callback(pltablex.values(data), code, headers)
        end
    end

    local cachedCount = 0
    local maxIdsPerQuery = 10
    local url = {
        path='/api/lol/${region}/v${version}/league/by-${idtype}/${ids}',
        params={version=self.version,idtype=idtype},
    }

    for index,id in ipairs(ids) do
        local cachedEntries = cache:get(cacheKeyForId(id, idtype))

        if cachedEntries then
            for _,entry in ipairs(cachedEntries) do
                local leagueKey = cacheKeyForLeague(entry.queue, entry.tier)
                cachedLeagues[leagueKey] = cache:get(leagueKey)
            end
            cachedCount = cachedCount + 1
        else
            local idString = url.params.ids
            url.params.ids = idString and idString..','..id or id

            if (index - cachedCount) % maxIdsPerQuery == 0 then
                self.api:get(url, onResponse)
                url.params.ids = nil
            end
        end
    end

    if url.params.ids then
        self.api:get(url, onResponse)
    end

    cachedLeagues = pltablex.values(cachedLeagues)
    if #cachedLeagues > 0 and opts.callback then
        opts.callback(cachedLeagues)
    end
end

--- Get a list of leagues by Summoner id
-- @tparam long summonerId the id of the Summoner whose leagues you wish to retreive
-- @tparam table opts a table of optional parameters
--
--   * `expire:` how long in seconds to cache a response (defaults to 1 week, _i.e. 7\*24\*60\*60_)
--   * `callback:` a callback which receives the response from the API (data, code, headers)
--
-- 
-- @function league:getBySummonerId
function _league:getBySummonerId(summonerId, opts)
    return self:getBySummonerIds({summonerId}, opts)
end

--- Get a list of leagues by Summoner ids
-- @tparam table summonerIds an array-like table with the list of Summoner ids whose leagues you wish to retreive
-- @tparam table opts a table of optional parameters
--
--   * `expire:` how long in seconds to cache a response (defaults to 1 week, _i.e. 7\*24\*60\*60_)
--   * `callback:` a callback which receives the response from the API (data, code, headers)
--
-- 
-- @function league:getBySummonerIds
function _league:getBySummonerIds(summonerIds, opts)
    return self:getByIds(summonerIds, 'summoner', opts)
end

--- Get a list of leagues by Team id
-- @tparam long teamId the id of the Team whose leagues you wish to retreive
-- @tparam table opts a table of optional parameters
--
--   * `expire:` how long in seconds to cache a response (defaults to 1 week, _i.e. 7\*24\*60\*60_)
--   * `callback:` a callback which receives the response from the API (data, code, headers)
--
-- 
-- @function league:getByTeamId
function _league:getByTeamId(teamId, opts)
    return self:getByTeamIds({teamId}, opts)
end

--- Get a list of leagues by Team ids
-- @tparam table teamIds an array-like table with the list of Team ids whose leagues you wish to retreive
-- @tparam table opts a table of optional parameters
--
--   * `expire:` how long in seconds to cache a response (defaults to 1 week, _i.e. 7\*24\*60\*60_)
--   * `callback:` a callback which receives the response from the API (data, code, headers)
--
-- 
-- @function league:getByTeamIds
function _league:getByTeamIds(teamIds, opts)
    return self:getByIds(teamIds, 'team', opts)
end

--- Get a list of league entires by Summoner or Team ids
-- @tparam table ids an array-like table with the list of Summoner or Team ids whose league entries you wish to retreive
-- @tparam string idtype a string which is either 'summoner' or 'team' denoting the type of ids passed in
-- @tparam table opts a table of optional parameters
--
--   * `expire:` how long in seconds to cache a response (defaults to 1 week, _i.e. 7\*24\*60\*60_)
--   * `callback:` a callback which receives the response from the API (data, code, headers)
--
-- 
-- @function league:getEntryByIds
function _league:getEntryByIds(ids, idtype, opts)
    opts = opts or {}

    plutils.assert_arg(1,ids,'table')
    plutils.assert_arg(2,idtype,'string',function() return self.IdTypes[idtype] end,'not a valid id type')
    plutils.assert_arg(3,opts,'table')

    local cache = self.api.cache
    local expire = opts.expire or 7*24*60*60
    local onResponse = function(res, code, headers)
        local data = {}
        for id,leagues in pairs(res) do
            data[id] = data[id] or {}

            local cacheKey = cacheKeyForId(id, idtype)
            for _,league in ipairs(leagues) do
                local leagueCacheKey = cacheKeyForLeague(league.queue, league.tier)
                local cachedLeague = cache:get(leagueCacheKey)

                -- there should only be one entry per league from this api query
                local entry = league.entries[1]

                -- if a cache entry already exists for this summoner or team, simply update the
                -- league entry for the particular league rather than overwriting the entire
                -- list of entries

                -- find the existing cached entry
                local cacheData = cache:get(cacheKey) or {}
                local entryIndex = #cacheData+1
                for index,cachedEntry in ipairs(cacheData) do
                    if cachedEntry.queue == league.queue and cachedEntry.tier == league.tier then
                        entryIndex = index
                        break
                    end
                end

                -- add the queue and tier to the entry
                entry.queue = league.queue
                entry.tier = league.tier
                table.insert(data[id], entry)

                cacheData[entryIndex] = entry
                cache:set(cacheKey,cacheData,expire)

                -- if there is a league already cached for this summoner or team make sure
                -- to update the league data in the cache
                if cachedLeague then
                    local leagueEntryIndex = #(cachedLeague.entries)
                    for index,cachedEntry in ipairs(cachedLeague.entries) do
                        if cachedEntry.playerOrTeamId == id then
                            leagueEntryIndex = index
                            break
                        end
                    end

                    cachedLeague.entries[leagueEntryIndex] = entry
                    cache:set(leagueCacheKey,cachedLeague,expire)
                end
            end
        end

        if opts.callback then
            opts.callback(data, code, headers)
        end
    end

    local cachedData = {}
    local cachedCount = 0
    local maxIdsPerQuery = 10
    local url = {
        path='/api/lol/${region}/v${version}/league/by-${idtype}/${ids}/entry',
        params={version=self.version,idtype=idtype},
    }

    for index,id in ipairs(ids) do
        local cachedEntries = cache:get(cacheKeyForId(id, idtype))

        if cachedEntries then
            cachedData[tostring(id)] = cachedEntries
            cachedCount = cachedCount + 1
        else
            local idString = url.params.ids
            url.params.ids = idString and idString..','..id or id

            if (index - cachedCount) % maxIdsPerQuery == 0 then
                self.api:get(url, onResponse)
                url.params.ids = nil
            end
        end
    end

    if url.params.ids then
        self.api:get(url, onResponse)
    end

    if cachedCount > 0 and opts.callback then
        opts.callback(cachedData)
    end
end

--- Get a league entry by Summoner id
-- @tparam long summonerId the id of the Summoner whose league entry you wish to retreive
-- @tparam table opts a table of optional parameters
--
--   * `expire:` how long in seconds to cache a response (defaults to 1 week, _i.e. 7\*24\*60\*60_)
--   * `callback:` a callback which receives the response from the API (data, code, headers)
--
-- 
-- @function league:getEntryBySummonerId
function _league:getEntryBySummonerId(summonerId, opts)
    return self:getEntryBySummonerIds({summonerId}, opts)
end

--- Get a list of league entires by Summoner ids
-- @tparam table summonerIds an array-like table with the list of Summoner ids whose league entries you wish to retreive
-- @tparam table opts a table of optional parameters
--
--   * `expire:` how long in seconds to cache a response (defaults to 1 week, _i.e. 7\*24\*60\*60_)
--   * `callback:` a callback which receives the response from the API (data, code, headers)
--
-- 
-- @function league:getEntryBySummonerIds
function _league:getEntryBySummonerIds(summonerIds, opts)
    return self:getEntryByIds(summonerIds, 'summoner', opts)
end

--- Get a league entry by Team id
-- @tparam long teamId the id of the Team whose league entry you wish to retreive
-- @tparam table opts a table of optional parameters
--
--   * `expire:` how long in seconds to cache a response (defaults to 1 week, _i.e. 7\*24\*60\*60_)
--   * `callback:` a callback which receives the response from the API (data, code, headers)
--
-- 
-- @function league:getEntryByTeamId
function _league:getEntryByTeamId(teamId, opts)
    return self:getEntryByTeamIds({teamId}, opts)
end

--- Get a list of league entires by Team ids
-- @tparam table teamIds an array-like table with the list of Team ids whose league entries you wish to retreive
-- @tparam table opts a table of optional parameters
--
--   * `expire:` how long in seconds to cache a response (defaults to 1 week, _i.e. 7\*24\*60\*60_)
--   * `callback:` a callback which receives the response from the API (data, code, headers)
--
-- 
-- @function league:getEntryByTeamIds
function _league:getEntryByTeamIds(teamIds, opts)
    return self:getEntryByIds(teamIds, 'team', opts)
end

return _league
