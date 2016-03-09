--- Basic access to the League of Legends API
--
-- This module is one of the core modules that everything is built on top of.
-- If you want to use any of the premade endpoint modules such as
-- 'lol.summoner' you will need to create an api object first and then use that
-- to create the specific endpoint module.
--
-- @module lol.api

local cache = require('lol.cache')
local cjson = require('cjson')
local file = require('pl.file')
local https = require('ssl.https')
local path = require('pl.path')
local stringx = require('pl.stringx')
local table = require('table')
local tablex = require('pl.tablex')
local text = require('pl.text')
local url = require('pl.url')
local utils = require('pl.utils')

local regions = {
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

local _api = {}
_api.__index = _api
setmetatable(_api, {
    __call = function(_,keyfile,regionid,cachedir,options)
        return _api.new(keyfile,regionid,cachedir,options)
    end})

--- Create a new api object which is bound to a region and a specific cache
-- @param keyfile - location of the file with the League of Legends API Key in it
-- @param regionid - the id of the region to speak to (see https://developer.riotgames.com/docs/regional-endpoints)
-- @param cachedir - a directory to cache responses from the API (NOTE: a subdirectory will be made for the region inside the cache directory)
-- @param options - a table with optional parameters, currently the only optional parameter is setting verbose to true
-- @return a new api object
-- @function api
function _api.new(keyfile, regionid, cachedir, options)
    utils.assert_arg(1,keyfile,'string',path.isfile,'not a file')
    utils.assert_arg(2,regionid,'string',function(id) return regions[id] end,'not a valid region')

    local apiCache
    if cachedir then
        utils.assert_arg(3,cachedir,'string',path.isdir,'not a directory')

        local dir = cachedir..path.sep..regionid
        if not path.isdir(dir) then
            path.mkdir(dir)
        end

        apiCache = cache(dir)
    end

    local obj = {}
    obj.cache = apiCache
    obj.key = stringx.strip(file.read(keyfile))
    obj.region = regions[regionid]
    obj.options = options or {}

    return setmetatable(obj, _api)
end

--- Check if the passed in table is a valid api object
-- @param obj - object to validate
-- @return true if valid, false otherwise
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

    if not tablex.search(regions,obj.region) then
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

--- Make a get request to the League of Legends API
-- @param turl - a table with the url parameters
--   * path - a string path using ${variable} for replaceable components
--   * params - the values of the variables used in the path, note that ${region} and ${platformId} are automatically filled in so no need to specify them
--   * query - table of query key/value pairs
-- @param callback - an optional callback function
-- @return true if valid, false otherwise
function _api:get(turl, callback)
    local urlString = self:buildUrlString(turl)
    if self.options.verbose then print(urlString) end

    local res, code, headers, status = https.request(urlString)
    if self.options.verbose then print(status) end

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
