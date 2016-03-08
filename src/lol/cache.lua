--- Basic caching for the League of Legends API
--
-- This module is one of the core modules that everything is built on top of.
-- If you want to create an api object, a cache object will be created for you
-- automatically.
--
-- @module lol.cache

--[[
--This is unfortunately a super dumb (and thus likely VERY slow) implementation
--of a cache. While I want a better implementation, and in fact tried to see if
--there was already a good cache written in lua, I'll use this for now and see
--about updating it in the future with something much more reasonable. For the
--time being it will have to suffice.
--]]
local cjson = require('cjson')
local crypto = require('crypto')
local dir = require('pl.dir')
local file = require('pl.file')
local os = require('os')
local path = require('pl.path')
local utils = require('pl.utils')

local _cache = {}
_cache.__index = _cache
setmetatable(_cache, {
    __call = function(_,cacheDir)
        return _cache.new(cacheDir)
    end})

--- Create a new cache object
-- @param cacheDir - the directory where to store cache entries
-- @return a new cache object
-- @function cache
function _cache.new(cacheDir)
    utils.assert_arg(1,path.abspath(cacheDir),'string',path.isdir,'not a directory')

    local obj = {}
    obj.cache = {}
    obj.dir = path.abspath(cacheDir)

    return setmetatable(obj, _cache)
end

local function isExpired(entry)
    return entry and entry.expires and os.difftime(entry.expires, os.time()) < 0
end

--- Clear all entries from the cache. This includes on disk and in memory.
function _cache:clearAll()
    self.cache = {}
    for _,cacheFile in pairs(dir.getfiles(self.dir)) do
        file.delete(cacheFile)
    end
end

--- Clear all expired entries from the cache. This includes on disk and in memory.
function _cache:clearExpired()
    for digest,entry in pairs(self.cache) do
        if isExpired(entry) then
            self.cache[digest] = nil
            file.delete(entry.file)
        end
    end

    for _,cacheFile in pairs(dir.getfiles(self.dir)) do
        local entry = cjson.decode(file.read(cacheFile))
        if isExpired(entry) then
            file.delete(cacheFile)
        end
    end
end

local function getFilename(basedir, digest)
    return basedir..path.sep..digest
end

local function getFromDisk(basedir, digest)
    local entry
    local cacheFile = getFilename(basedir, digest)

    if path.exists(cacheFile) then
        entry = cjson.decode(file.read(cacheFile))
        entry.file = cacheFile
    end

    return entry
end

--- Get an entry from the cache if it exists and hasn't expired.
-- @param key - the key of the entry to find
-- @return the value that was previously stored for that key
function _cache:get(key)
    -- First check the in memory cache
    local keyString = cjson.encode(key)
    local digest = crypto.digest('md5', keyString)
    local entry = self.cache[digest]

    -- If not found, search the disk cache
    entry = entry or getFromDisk(self.dir, digest)

    -- Then check for expiration
    if isExpired(entry) then
        file.delete(entry.file)
        entry = nil
    end

    -- Finally update the value in case it's expired
    self.cache[digest] = entry
    return entry and entry.value or nil
end

--- Add an entry to the cache with an optional number of seconds before expiration
-- @param key - the key of the entry to store
-- @param value - the value of the entry to store
-- @param expireSecs - optional number of seconds before the entry expires
function _cache:set(key, value, expireSecs)
    local entry = {value=value}
    local keyString = cjson.encode(key)

    if expireSecs then
        local expireDate = os.date('*t')
        expireDate.sec = expireDate.sec + expireSecs
        entry.expires = os.time(expireDate)
    end

    local digest = crypto.digest('md5', keyString)
    local cacheFile = getFilename(self.dir, digest)
    file.write(cacheFile, cjson.encode(entry))

    self.cache[digest] = entry
    entry.file = cacheFile
end

return _cache
