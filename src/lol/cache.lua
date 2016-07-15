--- Basic caching for the League of Legends API
--
-- This module is one of the core modules that everything is built on top of.
-- If you want to create an `api` object, a `cache` object will be created for you
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
local tablex = require('pl.tablex')
local utils = require('pl.utils')

local queue = {}
queue.__index = queue
setmetatable(queue, {
    __call = function(_,maxLen)
        return queue.new(maxLen)
    end})

function queue.new(maxLen)
    local obj = {}
    obj.maxLen = maxLen
    obj.list = {first=1,last=0,count=0}

    return setmetatable(obj, queue)
end

function queue:push(value)
    local list = self.list
    local last = list.last + 1
    list.count = list.count + 1

    list.last = last
    list[last] = value

    if self.maxLen and list.count > self.maxLen then
        return self:pop()
    end
end

function queue:pop()
    local list = self.list
    local first = list.first
    if first > list.last then error("list is empty") end

    local value = list[first]
    list[first] = nil -- to allow garbage collection
    list.first = first + 1
    list.count = list.count - 1

    self:skipEmpty()

    return value
end

function queue:skipEmpty()
    local list = self.list
    while list[list.first] == nil and list.first <= list.last do
        list.first = list.first + 1
    end
end

function queue:clear()
    self.list = {first=1,last=0,count=0}
end

function queue:remove(entries)
    local list = self.list
    for k, v in ipairs(list) do
        if entries[v] then
            list.count = list.count - 1
            list[k] = nil
        end
    end

    self:skipEmpty()
end


--- This class encapsulates making adding and retreiving elements from a cache
-- @type cache
local _cache = {}
_cache.__index = _cache
setmetatable(_cache, {
    __call = function(_,cacheDir,opts)
        return _cache.new(cacheDir,opts)
    end})

local function initialize(obj)
    -- clear any expired entries, it additionally clears out any bogus data
    -- (this can happen if you kill lua while it is writing out a cache file)
    -- and returns a sorted list of cached files by last access time.
    local _, cachedFiles = _cache.clearExpired(obj)

    -- go through on disk files and see if we have too many, then
    -- remove based on last accessed time
    for cacheFile,_ in cachedFiles do
        local removed = obj.cacheSize.disk.entries:push(cacheFile)
        if removed then
            local ok,err = file.delete(removed)
            if not ok and obj.opts.verbose then
                print(err)
            end
        end
    end
end

--- Create a new cache object
-- @tparam string cacheDir the directory where to store cache entries
-- @tparam table opts a table of optional parameters
-- @tparam boolean opts.weak a boolean which denotes if the in memory cache should be a weak table (i.e. allow
-- the entries to be garabage collected unless something external is holding onto them). Note that this will
-- not effect the entry being removed from disk, only from memory. So if you try to retreive it in the future
-- (and it hasn't expired) it will still be found in the cache. This option *DOES NOT WORK WITH `cacheSize`*,
-- so do not specify a memory `cacheSize` if you specify `weak`.
-- @tparam table opts.cacheSize a table which describes the size of the cache. The table can have two entries:
-- `memory` and `disk` which are tables of the form {count = x, size = y}, where `count` is the maximum number
-- of elements to keep and `size` is the maximum size in bytes.
-- @return a new cache object
-- @function cache:cache
function _cache.new(cacheDir, opts)
    utils.assert_arg(1,path.abspath(cacheDir),'string',path.isdir,'not a directory')

    local obj = {}
    obj.dir = path.abspath(cacheDir)
    obj.opts = opts or {}

    obj.cache = {}
    if obj.opts.weak then
        setmetatable(obj.cache, {__mode='kv'})
    end

    obj.maxCacheSize = obj.opts.cacheSize or {}
    for _,storage in pairs{'disk', 'memory'} do
        obj.maxCacheSize[storage] = obj.maxCacheSize[storage] or {}
        obj.maxCacheSize[storage].size = obj.maxCacheSize[storage].size or math.huge
        obj.maxCacheSize[storage].count = obj.maxCacheSize[storage].count or math.huge
    end

    obj.cacheSize = {
        disk={bytes=0,entries=queue(obj.maxCacheSize.disk.count)},
        memory={bytes=0,entries=queue(obj.maxCacheSize.memory.count)}
    }

    initialize(obj)
    return setmetatable(obj, _cache)
end

local function isExpired(entry)
    return entry and entry.expires and os.difftime(entry.expires, os.time()) < 0
end

--- Drops all cache entries from memory, but keeps them in the disk cache. This can be used to save memory in lua.
-- @function cache:dropAll
function _cache:dropAll()
    self.cache = {}
    self.cacheSize.memory.bytes = 0
    self.cacheSize.memory.entries:clear()

    collectgarbage()
end

--- Clear all entries from the cache. This includes on disk and in memory.
-- @function cache:clearAll
function _cache:clearAll()
    self:dropAll()
    for _,cacheFile in pairs(dir.getfiles(self.dir)) do
        local ok,err = file.delete(cacheFile)
        if not ok and self.opts.verbose then
            print(err)
        end
    end

    self.cacheSize.disk.bytes = 0
    self.cacheSize.disk.entries:clear()
end

--- Clear all expired entries from the cache. This includes on disk and in memory.
-- @function cache:clearExpired
function _cache:clearExpired()
    local removed = {}
    for digest,entry in pairs(self.cache) do
        if isExpired(entry) then
            self.cache[digest] = nil
            local ok,err = file.delete(entry.file)
            if ok then
                removed[digest] = true
            elseif self.opts.verbose then
                print(err)
            end
        end
    end

    local cachedFiles = {}
    for _,cacheFile in pairs(dir.getfiles(self.dir)) do
        local data = file.read(cacheFile)
        local ok,entry = pcall(function() return cjson.decode(data) end)
        if not ok or isExpired(entry) then
            local err
            ok,err = file.delete(cacheFile)
            if ok then
                local digest = string.match(cacheFile, self.dir..path.sep..'(.+)')
                removed[digest] = true
            elseif self.opts.verbose then
                print(err)
            end
        else
            cachedFiles[cacheFile] = file.access_time(cacheFile)
        end
    end

    self.cacheSize.disk.entries:remove(removed)
    self.cacheSize.memory.entries:remove(removed)

    return removed, tablex.sortv(cachedFiles)
end

local function getFilename(basedir, digest)
    return basedir..path.sep..digest
end

local function getFromDisk(basedir, digest)
    local entry
    local cacheFile = getFilename(basedir, digest)

    if path.exists(cacheFile) then
        local ok
        local data = file.read(cacheFile)
        ok,entry = pcall(function() return cjson.decode(data) end)
        if ok then
            entry.file = cacheFile
        end
    end

    return entry
end

--- Remove an entry from the cache.
-- @param key the key of the entry to find (**must be convertible to JSON**)
-- @function cache:remove
function _cache:remove(key)
    -- First check the in memory cache
    local keyString = cjson.encode(key)
    local digest = crypto.digest('md5', keyString)

    local remove = {[digest]=true}
    self.cacheSize.disk.entries:remove(remove)
    self.cacheSize.memory.entries:remove(remove)

    local entry = getFromDisk(self.dir, digest)
    if entry then
        local ok, err = file.delete(entry.file)
        if not ok and self.opts.verbose then
            print(err)
        end
    end

    self.cache[digest] = nil
end

--- Get an entry from the cache if it exists and hasn't expired.
-- @param key the key of the entry to find (**must be convertible to JSON**)
-- @return the value that was previously stored for the given key
-- @function cache:get
function _cache:get(key)
    -- First check the in memory cache
    local keyString = cjson.encode(key)
    local digest = crypto.digest('md5', keyString)
    local entry = self.cache[digest]

    -- If not found, search the disk cache
    entry = entry or getFromDisk(self.dir, digest)

    -- Then check for expiration
    if isExpired(entry) then
        local remove = {[digest]=true}
        self.cacheSize.disk.entries:remove(remove)
        self.cacheSize.memory.entries:remove(remove)

        local ok, err = file.delete(entry.file)
        if not ok and self.opts.verbose then
            print(err)
        end
        entry = nil
    end

    -- Finally update the value in case it's expired
    -- First remove from the in memory cache if needed
    local removed = self.cacheSize.memory.entries:push(digest)
    if removed then
        self.cache[removed] = nil
    end
    self.cache[digest] = entry
    return entry and entry.value or nil
end

--- Add an entry to the cache with an optional number of seconds before expiration
-- @param key the key of the entry to store (**must be convertible to JSON**)
-- @param value the value of the entry to store (**must be convertible to JSON**)
-- @param expires optional number of seconds before the entry expires
-- @function cache:set
function _cache:set(key, value, expires)
    local entry = {value=value}
    local keyString = cjson.encode(key)

    if expires then
        local expireDate = os.date('*t')
        expireDate.sec = expireDate.sec + expires
        entry.expires = os.time(expireDate)
    end

    local digest = crypto.digest('md5', keyString)
    local cacheFile = getFilename(self.dir, digest)

    -- If adding the file to disk would cause max entries to be exceeded then remove the last used entry
    local removed = self.cacheSize.disk.entries:push(digest)
    if removed then
        local removedFile = getFilename(self.dir, removed)
        local ok,err = file.delete(removedFile)
        if not ok and self.opts.verbose then
            print(err)
        end
    end
    file.write(cacheFile, cjson.encode(entry))

    -- Similarly remove from in memory cache if needed
    removed = self.cacheSize.memory.entries:push(digest)
    if removed then
        self.cache[removed] = nil
    end
    self.cache[digest] = entry
    entry.file = cacheFile
end

return _cache
