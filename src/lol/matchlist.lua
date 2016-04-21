--- Allows for making queries against the League of Legends Matchlist API
--
-- By first creating an api object and creating a new matchlist object from it
-- you can then make queries against the League of Legends Summoner API.
--
-- @module lol.matchlist

local api = require('lol.api')
local utils = require('lol.utils')
local plutils = require('pl.utils')

--- This class encapsulates manipulating the League of Legends Matchlist API
-- @type matchlist
local _matchlist = {
    --- The seasons available to filter on
    Seasons = {
        PRESEASON3=true, -- Preseason 3
        SEASON3=true, -- Season 3
        PRESEASON2014=true, -- Preseason 2014
        SEASON2014=true, -- Season 2014
        PRESEASON2015=true, -- Preseason 2015
        SEASON2015=true, -- Season 2015
        PRESEASON2016=true, -- Preseason 2016
        SEASON2016=true, -- Season 2016
    },

    --- The ranked queues available to filter on
    RankedQueues = {
        TEAM_BUILDER_DRAFT_RANKED_5x5=true, -- Team Builder Draft Ranked 5x5
        RANKED_SOLO_5x5=true, -- Ranked Solo 5x5
        RANKED_TEAM_3x3=true, -- Ranked Team 3x3
        RANKED_TEAM_5x5=true, -- Ranked Team 5x5
    }
}
_matchlist.__index = _matchlist
setmetatable(_matchlist, {
    __call = function(_,apiObj)
        return _matchlist.new(apiObj)
    end})

--- Create a new matchlist object
-- @param api the @{api} object that communicates with the League of Legends server
-- @return a new matchlist object
-- @function matchlist:matchlist
function _matchlist.new(apiObj)
    plutils.assert_arg(1,apiObj,'table',api.isvalid,'not a valid api object')

    local obj = {}
    obj.api = apiObj
    obj.version = '2.2'

    return setmetatable(obj, _matchlist)
end

--- Validates that the passed in filters for correctness
-- @tparam table filters a table specifying how to filter the matchlist
-- @tparam table filters.championIds an array-like table of champion IDs to use for fetching games.
-- @tparam table filters.seasons an array-like table of @{Seasons|seasons} to use for fetching games,
-- @tparam table filters.rankedQueues an array-like table of @{RankedQueues|ranked queue} types to use for fetching games, 
-- @tparam long filters.beginTime the begin time to use for fetching games specified as epoch milliseconds
-- @tparam long filters.endTime the end time to use for fetching games specified as epoch milliseconds
-- @tparam long filters.beginIndex the begin index to use for fetching games
-- @tparam long filters.endIndex the end index to use for fetching games
-- @return a new matchlist object
-- @remark This method may mutate the passed in filters to make them valid (such as swapping `beginIndex` and `endIndex`)
-- @function matchlist.validateFilters
function _matchlist.validateFilters(filters)
    local championIds = filters.championIds or {}
    if type (championIds) ~= 'table' then
        return false
    end

    for _,id in ipairs(championIds) do
        if type(id) ~= 'number' then
            return false
        end
    end

    local rankedQueues = filters.rankedQueues or {}
    if type (rankedQueues) ~= 'table' then
        return false
    end

    for _,queue in ipairs(rankedQueues) do
        if not _matchlist.RankedQueues[queue] then
            return false
        end
    end

    local seasons = filters.seasons or {}
    if type (seasons) ~= 'table' then
        return false
    end

    for _,season in ipairs(seasons) do
        if not _matchlist.Seasons[season] then
            return false
        end
    end

    -- if either one or the other is specified they both must be specified,
    -- make sure to specify them to sensible defaults in the case only one is
    -- specified
    if filters.beginIndex or filters.endIndex then
        local beginIndex = filters.beginIndex or 0
        if type(beginIndex) ~= 'number' then
            return false
        end

        local endIndex = filters.endIndex
        if endIndex then
            if type(endIndex) ~= 'number' then
                return false
            end

            filters.beginIndex = math.min(beginIndex, endIndex)
            filters.endIndex = math.max(beginIndex, endIndex)
        end
    end

    -- if either one or the other is specified they both must be specified,
    -- make sure to specify them to sensible defaults in the case only one is
    -- specified
    if filters.beginTime or filters.endTime then
        local beginTime = filters.beginTime or 0
        local endTime = filters.endTime or utils.epoch()

        if type(beginTime) ~= 'number' or type(endTime) ~= 'number' then
            return false
        end

        -- make sure they are properly ordered
        filters.beginTime = math.min(beginTime, endTime)
        filters.endTime = math.max(beginTime, endTime)
    end

    return true
end

--- Validates that the passed in filters for correctness
-- @tparam table filters a table specifying how to filter the matchlist
-- @tparam table filters.championIds an array-like table of champion IDs to use for fetching games.
-- @tparam table filters.seasons an array-like table of @{Seasons|seasons} to use for fetching games,
-- @tparam table filters.rankedQueues an array-like table of @{RankedQueues|ranked queue} types to use for fetching games, 
-- @tparam long filters.beginTime the begin time to use for fetching games specified as epoch milliseconds
-- @tparam long filters.endTime the end time to use for fetching games specified as epoch milliseconds
-- @tparam long filters.beginIndex the begin index to use for fetching games
-- @tparam long filters.endIndex the end index to use for fetching games
-- @return a new matchlist object
-- @remark This method may mutate the passed in filters to make them valid (such as swapping `beginIndex` and `endIndex`)
-- @function matchlist.buildQuery
function _matchlist.buildQuery(filters)
    plutils.assert_arg(1,filters,'table',_matchlist.validateFilters,'invalid filters specified')

    local query = {}
    local strFields = {'championIds', 'rankedQueues', 'seasons'}
    for _,field in ipairs(strFields) do
        if filters[field] then
            query[field] = table.concat(filters[field], ',')
        end
    end

    local numFields = {'beginIndex', 'endIndex', 'beginTime', 'endTime'}
    for _,field in ipairs(numFields) do
        query[field] = filters[field]
    end

    return query
end

--- Get a list of matches by Summoner id that statisfy the passed in filters
-- @tparam long summonerId the id of the Summoner whose matchlist you wish to retreive
-- @tparam table opts a table of optional parameters
--
--   * `expire:` how long in seconds to cache a response (defaults to 1 hour, _i.e. 60\*60_)
--   * `filters:` a table specifying how to filter the matchlist
--     * `championIds:` an array-like table of champion IDs to use for fetching games.
--     * `seasons:` an array-like table of @{Seasons|seasons} to use for fetching games,
--     * `rankedQueues:` an array-like table of @{RankedQueues|ranked queue} types to use for fetching games,
--     * `beginTime:` the begin time to use for fetching games specified as epoch milliseconds
--     * `endTime:` the end time to use for fetching games specified as epoch milliseconds
--     * `beginIndex:` the begin index to use for fetching games
--     * `endIndex:` the end index to use for fetching games
--   * `callback:` a callback which receives the response from the API (data, code, headers)
--
-- 
-- @function matchlist:getBySummonerId
function _matchlist:getBySummonerId(summonerId, opts)
    opts = opts or {}

    local cache = self.api.cache
    local filters = opts.filters or {}
    local query = _matchlist.buildQuery(filters)
    local cacheKey = {api='matchlist',summonerId=summonerId,query=query}
    local expire = opts.expire or 60*60
    local onResponse = function(res, code, headers)
        if code and code == 200 then
            cache:set(cacheKey,res,expire)
        end

        if opts.callback then
            opts.callback(res, code, headers)
        end
    end

    local matchlist = cache:get(cacheKey)
    if matchlist and opts.callback then
        opts.callback(matchlist)
    else
        local url = {
            path='/api/lol/${region}/v${version}/matchlist/by-summoner/${summonerId}',
            params={version=self.version,summonerId=summonerId},
            query=query
        }
        self.api:get(url, onResponse)
    end
end

return _matchlist
