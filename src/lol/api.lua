--- Basic access to the League of Legends API
--
-- This module is one of the core modules that everything is built on top of.
-- If you want to use any of the premade endpoint modules such as
-- `lol.summoner` you will need to create an api object first and then use that
-- to create the specific endpoint module.
--
-- @module lol.api

local cache = require('lol.cache')
local cjson = require('cjson')
local file = require('pl.file')
local https = require('ssl.https')
local path = require('pl.path')
local socket = require('socket')
local stringx = require('pl.stringx')
local table = require('table')
local tablex = require('pl.tablex')
local text = require('pl.text')
local url = require('pl.url')
local utils = require('pl.utils')

--- This class encapsulates making requests again the League of Legends API
-- @type api
local _api = {
    Regions = {
        br = { id = 'br',  platformId = 'BR1', host = 'https://br.api.pvp.net' },
        eune = { id = 'eune',  platformId = 'EUN1', host = 'https://eune.api.pvp.net' },
        euw = { id = 'euw',  platformId = 'EUW1', host = 'https://euw.api.pvp.net' },
        kr = { id = 'kr',  platformId = 'KR', host = 'https://kr.api.pvp.net' },
        lan = { id = 'lan',  platformId = 'LA1', host = 'https://lan.api.pvp.net' },
        las = { id = 'las',  platformId = 'LA2', host = 'https://las.api.pvp.net' },
        na = { id = 'na',  platformId = 'NA1', host = 'https://na.api.pvp.net' },
        oce = { id = 'oce',  platformId = 'OC1', host = 'https://oce.api.pvp.net' },
        tr = { id = 'tr',  platformId = 'TR1', host = 'https://tr.api.pvp.net' },
        ru = { id = 'ru',  platformId = 'RU', host = 'https://ru.api.pvp.net' },
        pbe = { id = 'pbe',  platformId = 'PBE1', host = 'https://pbe.api.pvp.net'  }
    }
}
_api.__index = _api
setmetatable(_api, {
    __call = function(_,keyfile,regionid,cachedir,opts)
        return _api.new(keyfile,regionid,cachedir,opts)
    end
})

--- The list of valid regions that are available see [Regional Endpoints](https://developer.riotgames.com/docs/regional-endpoints).
-- @field br **br.api.pvp.net**
-- @field eune **eune.api.pvp.net**
-- @field euw **euw.api.pvp.net**
-- @field kr **kr.api.pvp.net**
-- @field lan **lan.api.pvp.net**
-- @field las **las.api.pvp.net**
-- @field na **na.api.pvp.net**
-- @field oce **oce.api.pvp.net**
-- @field tr **tr.api.pvp.net**
-- @field ru **ru.api.pvp.net**
-- @field pbe **pbe.api.pvp.net**
-- @table api.Regions

--- Create a new api object which is bound to a region and a specific cache
-- @tparam string keyfile location of the file with the League of Legends API Key in it
-- @tparam string regionid the id of the @{Regions|regional endpoint} to get data from
-- @tparam string cachedir a directory to cache responses from the API (_NOTE_: a subdirectory will be made for the region inside the cache directory)
-- @tparam table opts a table with optional parameters (it gets passed to the cache as well)
-- @tparam bool opts.verbose whether to have verbose out when making API requests
-- @return a new api object
-- @function api:api
function _api.new(keyfile, regionid, cachedir, opts)
    utils.assert_arg(1,keyfile,'string',path.isfile,'not a file')
    utils.assert_arg(2,regionid,'string',function(id) return _api.Regions[id] end,'not a valid region')

    local apiCache
    if cachedir then
        utils.assert_arg(3,cachedir,'string',path.isdir,'not a directory')

        local dir = cachedir..path.sep..regionid
        if not path.isdir(dir) then
            path.mkdir(dir)
        end

        apiCache = cache(dir, opts)
    end

    local obj = {}
    obj.cache = apiCache
    obj.key = stringx.strip(file.read(keyfile))
    obj.region = _api.Regions[regionid]
    obj.opts = opts or {}

    return setmetatable(obj, _api)
end

--- Check if the passed in table is a valid api object
-- @param obj object to validate
-- @return true if valid, false otherwise
-- @function api.isvalid
function _api.isvalid(obj)
    if type(obj) ~= 'table' then
        return false
    end

    local mt = getmetatable(obj)
    if not mt or mt.__index ~= _api.__index then
        return false
    end

    if type(obj.key) ~= 'string' or #obj.key == 0 then
        return false
    end

    if not tablex.search(_api.Regions,obj.region) then
        return false
    end

    return true
end

function _api:buildUrlString(turl)
    local params = tablex.merge({region=self.region.id,platformId=self.region.platformId}, turl.params or {}, true)
    tablex.transform(function(v) return url.quote(tostring(v)) end, params)
    local pathString = text.Template(turl.path):substitute(params)

    local fullQuery = tablex.merge({api_key=self.key}, turl.query or {}, true)
    local queryString = table.concat(tablex.pairmap(function(k,v) return url.quote(tostring(k))..'='..url.quote(tostring(v)) end, fullQuery), '&')

    return self.region.host..pathString..'?'..queryString
end

-- These are codes that cause a retry of a get request
local retryOnCodes = {
    [429] = true, -- Rate limit exceeded
    [500] = true, -- Internal server error
    [503] = true, -- Service unavailable
}

--- Make a get request to the League of Legends API
-- @tparam table url a table with the url parameters
-- @tparam string url.path a string path using `${variable}` for replaceable components
-- @tparam table url.params the values of the variables used in the path (_NOTE_: `${region}` and `${platformId}` are automatically filled in so no need to specify them)
-- @tparam table url.query table of query key/value pairs
-- @tparam function callback an optional callback function
-- @return true if valid, false otherwise
-- @function api:get
function _api:get(turl, callback)
    local urlString = self:buildUrlString(turl)
    if self.opts.verbose then print(urlString) end

    if self.opts.rateLimits then
        self.rates = self.rates or {}

        for _, rateLimit in ipairs(self.opts.rateLimits) do
            if not self.rates[rateLimit] then
                self.rates[rateLimit] = { count = 0, intervalStart = os.time() }
            end

            -- When calculating the elapsed time subtract 1 in order to give ourselves a one
            -- second leeway between when we think the interval started to account for things
            -- such as processing speed and network latency. It's a crude measure, but should
            -- hopefully cause fewer potential rate limiting issues vs not having the buffer
            -- in there.
            local rate = self.rates[rateLimit]
            local elapsed = os.difftime(os.time(), rate.intervalStart) - 1
            if elapsed > rateLimit.interval then
                rate.count = 1
                rate.intervalStart = os.time()
            elseif rate.count + 1 > rateLimit.requests then
                -- wait until we should be allowed to make another request
                socket.sleep(rateLimit.interval - elapsed)

                rate.count = 1
                rate.intervalStart = os.time()
            else
                rate.count = rate.count + 1
            end
        end
    end

    local tries = 0
    local res, code, headers, status
    repeat
        tries = tries + 1
        res, code, headers, status = https.request(urlString)
        if self.opts.verbose then print(status) end
    until not retryOnCodes[code] or self.opts.maxRetries == nil or tries > self.opts.maxRetries

    if callback then
        if headers and headers['content-type'] and string.match(headers['content-type'],'application/json') then
            local ok,decoded = pcall(function() return cjson.decode(res) end)
            if ok then
                callback(decoded, code, headers)
            else
                callback(nil, code, headers)
            end
        else
            callback(res, code, headers)
        end
    end
end

return _api
