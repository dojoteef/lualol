## Introduction

### Purpose

This library is designed to be a simple way to interface with the League of
Legends API. The project started as a way to familiarize myself with the League
of Legends API and see if there were any interesting conclusions I could draw
from the available data using [torch](http://torch.ch). Since torch is a Lua
library for machine learning it made sense to make this library in Lua as well.

### Library Overview

The library is designed to support caching and closely mirror the way the League
of Legends API is structured. Each module is focused around one of the API
endpoints documented in the [Full API
Reference](https://developer.riotgames.com/api/methods).

### Examples

A list of examples are available in the `examples` directory. For a quick look
here is an example of using the summoner module:

    local lol = require('lol')
    local api = lol.api('keys/devel', 'na', 'cache')
    local summoner = lol.summoner(api)

    summoner:getByName('Calm the Violent', function(res, code)
        print(res)
    end)

As you can see in this simple example, we require the `lol` module then create
an object that encapsulates the API passing in the location of the [API
Key](https://developer.riotgames.com/docs/api-keys), the desired
[region](https://developer.riotgames.com/docs/regional-endpoints) and finally a
directory for the cache.

Then we create an instance of the summoner which encompasses that specific api
object and query for a summoner by name. Since the library uses
[async](https://github.com/clementfarabet/async) it uses a Node.js style
architecture so you pass in a callback that is executed when the result of the
API query returns. Note if the data is found in the cache it will also use the
callback without a status code returned.
