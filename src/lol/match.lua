--- Allows for making queries against the League of Legends Match API
--
-- By first creating an api object and creating a new match object from it
-- you can then make queries against the League of Legends Match API.
--
-- @module lol.match

local api = require('lol.api')
local utils = require('pl.utils')

--- This class encapsulates manipulating the League of Legends Match API
-- @type match
local _match = {}
_match.__index = _match
setmetatable(_match, {
    __call = function(_,apiObj)
        return _match.new(apiObj)
    end})

--- Create a new match object
-- @param api the @{api} object that communicates with the League of Legends server
-- @return a new match object
-- @function match:match
function _match.new(apiObj)
    utils.assert_arg(1,apiObj,'table',api.isvalid,'not a valid api object')

    local obj = {}
    obj.api = apiObj
    obj.version = '2.2'

    return setmetatable(obj, _match)
end

--- Get a match by match id
-- @tparam long matchId the id of the match to retreive
-- @tparam table opts a table with optional parameters:
-- @tparam boolean opts.includeTimeline whether to include timeline data
-- @tparam long opts.expire how long in seconds to cache a response (defaults to 30 days, _i.e. 30\*24\*60\*60_)
-- @tparam function opts.callback a callback which receives the response from the API (data, code, headers)
-- @function match:getById
function _match:getById(matchId, opts)
    opts = opts or {}

    utils.assert_arg(1,matchId,'number')
    utils.assert_arg(2,opts,'table')

    local cache = self.api.cache
    local cacheKey = {api='match',matchId=matchId}
    local expire = opts.expire or 30*24*60*60
    local onResponse = function(res, code, headers)
        if code and code == 200 then
            -- store off the fact that we tried to include timeline data so that
            -- we just use the cache if the api doesn't have timeline data for the match
            res.timeline = res.timeline or (opts.includeTimeline and {})
            cache:set(cacheKey,res,expire)
        end

        if opts.callback then
            opts.callback(res, code, headers)
        end
    end

    -- only use the cached match if they didn't request timeline data or if the cached match includes it
    local match = cache:get(cacheKey)
    if match and (match.timeline or not opts.includeTimeline) then
        if opts.callback then
            opts.callback(match)
        end
    else
        local url = {
            path='/api/lol/${region}/v${version}/match/${matchId}',
            params={version=self.version,matchId=matchId},
            query={includeTimeline=opts.includeTimeline}
        }
        self.api:get(url, onResponse)
    end
end

return _match
