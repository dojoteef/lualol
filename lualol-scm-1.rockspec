package = "lol"
version = "scm-1"

source = {
  --TODO
  --url = "git://github.com/dojoteef/lol.git",
  url = "...",
}

description = {
  summary = "A Lua library for accessing the League of Legends API",
  detailed = [[
    lol is an easy way to access the League of Legends API using Lua. It includes a simple caching
    mechanism that's built-in.
  ]],
  -- TODO
  --homepage = "http://dojoteef.github.com/lol",
  homepage = "http://...",
  maintainer = "dojoteef@gmail.com",
  license = "MIT/X11",
}

dependencies = {
  "penlight",
  "luasec",
  "luasocket",
}

build = {
  type = "builtin",
  modules = {
    ["lol"] = "src/lol/init.lua",
    ["lol.api"] = "src/lol/api.lua",
    ["lol.cache"] = "src/lol/cache.lua",
    ["lol.game"] = "src/lol/game.lua",
    ["lol.matchlist"] = "src/lol/matchlist.lua",
    ["lol.summoner"] = "src/lol/summoner.lua",
  },
  copy_directories = {"doc","tests"}
}
