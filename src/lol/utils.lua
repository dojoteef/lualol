--- Useful utility functions needed by the library
--
-- There are some useful utilities such as getting the epoch time that Lua
-- doesn't natively support which are defined in this module.
--
-- @module lol.utils

local _utils = {}

--- Lua doesn't have a portable way to get the epoch time (though for most
-- systems `os.time()` is epoch time). This is a simple way to get the epoch time
-- using just the Lua standard library functions that I believe should be
-- portable.
-- @param time an optional time parameter to find the epoch time of, if not provided it defaults to using `os.time()` (_NOTE_: The passed in time must be one gotten from `os.time()` on the current system)
-- @function utils.epoch
_utils.epoch = function(time)
    -- first get our local time offset
    local offset = os.date('!*t', os.time({year=1970,month=1,day=1,hour=0,min=0,sec=0}))

    -- then get the current time
    local desired = os.date('!*t', time or os.time())

    -- add the offset back into the desired time
    desired.hour = desired.hour + offset.hour
    desired.min = desired.min + offset.min
    desired.sec = desired.sec + offset.sec

    -- we can finally use os.difftime to give us the seconds between the two dates
    return os.difftime(os.time(desired), os.time(offset))
end

return _utils
