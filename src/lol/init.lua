--[[
--This is the LOL loader which can load LOL libraries on demand. Basically when
--a module is first attempted to be accessed it is implicitly loaded on demand.
--]]

local lol = {}
local modules = {
    api=true,cache=true,game=true,league=true,match=true,matchlist=true,summoner=true,utils=true
}

setmetatable(lol, {
    __index = function(table,key)
        if modules[key] then
            rawset(table,key,require('lol.'..key))
            return table[key]
        end
    end
})

return lol
