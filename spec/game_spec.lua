describe('lol.game', function()
    local game,match
    setup(function()
        game = require('lol.game')
        match = require('luassert.match')
    end)

    it('loaded okay', function()
        assert.not_nil(game)
    end)

    it('errors if given an invalid api obj', function()
        assert.has.errors(function() game({}) end)
    end)

    describe('game', function()
        local file, path
        local cacheDir, keyfile, testApi
        setup(function()
            file = require('pl.file')
            path = require('pl.path')

            cacheDir = '.testCache'
            if not path.isdir(cacheDir) then
                path.mkdir(cacheDir)
            end

            keyfile = '.test_keyfile'
            file.write(keyfile,'somerandomapikey')

            local api = require('lol.api')
            testApi = api(keyfile, 'na', cacheDir)
        end)

        teardown(function()
            file.delete(keyfile)

            if path.isdir(cacheDir) then
                local dir = require('pl.dir')
                dir.rmtree(cacheDir)
            end
        end)

        it('can be created', function()
            local testGame = game(testApi)
            assert.is.not_nil(testGame)
        end)

        it('has the correct API version', function()
            local testGame = game(testApi)
            assert.is_equal(testGame.version, '1.3')
        end)

        insulate('getBySummonerId', function()
            local testGame
            setup(function()
                testGame = game(testApi)
            end)

            before_each(function()
                testGame.api.cache:clearAll()
            end)

            it('uses api get on cache miss', function()
                local s1 = stub(testGame.api, 'get',function() end)
                testGame:getBySummonerId(123456789)

                assert.stub(s1).called(1)

                local url = {
                    path='/api/lol/${region}/v${version}/game/by-summoner/${summonerId}/recent',
                    params={version=testGame.version,summonerId=123456789},
                }
                assert.stub(s1).called_with(testGame.api, match.same(url),match.is_function())
                s1:revert()
            end)

            local cacheForXSecsFn = function(secs)
                local mockRes = {{summonerId=123456789}, 200, {}}

                local api = testGame.api
                local cache = api.cache
                local cacheSecs = secs or 5*60*60

                local s1 = spy.new(function() end)
                local s2 = stub(cache, 'set')
                local s3 = stub(api, 'get', function(_,_,c) c(unpack(mockRes)) end)
                testGame:getBySummonerId(123456789, {callback=s1,expire=secs})

                assert.spy(s1).called(1)
                assert.spy(s1).called_with(unpack(mockRes))

                local cacheKey = {api='game',summonerId=123456789}
                assert.stub(s2).called_with(cache,match.same(cacheKey),mockRes[1],cacheSecs)
                s2:revert()
                s3:revert()
            end

            it('caches api entries for 5 hours by default', function()
                cacheForXSecsFn()
            end)

            it('caches api entries for the specified amount of time', function()
                cacheForXSecsFn(60)
            end)

            it('will return previously cached entries', function()
                local mockDto = {summonerId=123456789}
                local cache = testGame.api.cache
                local s1 = spy.new(function() end)
                local s2 = stub(cache, 'get', function() return mockDto end)
                testGame:getBySummonerId(mockDto.summonerId, {callback=s1})

                assert.spy(s1).called(1)
                assert.spy(s1).called_with(mockDto)
                s2:revert()
            end)
        end)
    end)
end)
