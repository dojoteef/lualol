# LuaLoL - Lua Library for the League of Legends API

[![Build Status](https://travis-ci.org/dojoteef/lualol.svg)](https://travis-ci.org/dojoteef/lualol)
[![Coverage Status](https://coveralls.io/repos/github/dojoteef/lualol/badge.svg?branch=master)](https://coveralls.io/github/dojoteef/lualol?branch=master)

## What does LuaLoL do?

LuaLoL is a small test project I made for fetching data from the [League of Legends
API](http://developer.leagueoflegends.com). It's written in Lua since I wanted
to be able to pull data from the API and feed it to [torch](http://torch.ch) so
that I can run some analysis over the data.

## Module Overview

### Low Level Access

  * `api`: allows for direct access to the api
  * `cache`: module for caching of responses from the api can write to disk

### Application Specific Modules

  * `game`: this wraps the game League of Legends API calls
  * `match`: this wraps the match League of Legends API calls
  * `matchlist`: this wraps the matchlist League of Legends API calls
  * `league`: this wraps the league League of Legends API calls
  * `summoner`: this wraps the summoner League of Legends API calls

## Requirements

This library depends on [Penlight](https://github.com/stevedonovan/Penlight)
(pl), [LuaSocket](https://github.com/diegonehab/luasocket), 
[LuaSec](https://github.com/brunoos/luasec),
[LuaCrypto](https://github.com/mkottman/luacrypto), and
[lua-cjson](https://github.com/mpx/lua-cjson).

### Installation

The preferred method of installation is using [LuaRocks](https://luarocks.org) a
package manager for Lua. If you have Lua installed, simply type the following at
a terminal prompt:

    > luarocks install lualol

Note that if you are trying to install lualol on OSX from within torch's LuaRocks
installation you may need to use following command if you get an error about not
having [OpenSSL](https://www.openssl.org) installed.

    > luarocks install lualol OPENSSL_DIR=/usr/local/opt/openssl/

## Building the Documentation

Requires [ldoc](https://github.com/stevedonovan/LDoc), which is available
through LuaRocks.  Then it's a simple matter of running ldoc in the docs folder.

lualol/docs$ ldoc .
