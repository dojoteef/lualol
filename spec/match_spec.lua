describe('lol.match', function()
    local match,lmatch
    setup(function()
        match = require('lol.match')
        lmatch = require('luassert.match')
    end)

    it('loaded okay', function()
        assert.not_nil(match)
    end)

    it('errors if given an invalid api obj', function()
        assert.has.errors(function() match({}) end)
    end)

    describe('match', function()
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
            local testMatch = match(testApi)
            assert.is.not_nil(testMatch)
        end)

        it('has the correct API version', function()
            local testMatch = match(testApi)
            assert.is_equal(testMatch.version, '2.2')
        end)

        insulate('getById', function()
            local testMatch
            setup(function()
                testMatch = match(testApi)
            end)

            before_each(function()
                testMatch.api.cache:clearAll()
            end)

            it('uses api get on cache miss', function()
                local s1 = stub(testMatch.api, 'get',function() end)
                testMatch:getById(123456789)

                assert.stub(s1).called(1)

                local url = {
                    path='/api/lol/${region}/v${version}/match/${matchId}',
                    params={version=testMatch.version,matchId=123456789},
                    query={}
                }
                assert.stub(s1).called_with(testMatch.api, lmatch.same(url),lmatch.is_function())
                s1:revert()
            end)

            local cacheForXSecsFn = function(secs)
                local mockRes = {{matchId=123456789}, 200, {}}

                local api = testMatch.api
                local cache = api.cache
                local cacheSecs = secs or 30*24*60*60

                local s1 = spy.new(function() end)
                local s2 = stub(cache, 'set')
                local s3 = stub(api, 'get', function(_,_,c) c(unpack(mockRes)) end)
                testMatch:getById(123456789, {callback=s1,expire=secs})

                assert.spy(s1).called(1)
                assert.spy(s1).called_with(unpack(mockRes))

                local cacheKey = {api='match',matchId=123456789}
                assert.stub(s2).called_with(cache,lmatch.same(cacheKey),mockRes[1],cacheSecs)
                s2:revert()
                s3:revert()
            end

            it('caches api entries for 30 days by default', function()
                cacheForXSecsFn()
            end)

            it('caches api entries for the specified amount of time', function()
                cacheForXSecsFn(60)
            end)

            it('will return previously cached entries', function()
                local mockDto = {matchId=123456789}
                local cache = testMatch.api.cache
                local s1 = spy.new(function() end)
                local s2 = stub(cache, 'get', function() return mockDto end)
                testMatch:getById(mockDto.matchId, {callback=s1})

                assert.spy(s1).called(1)
                assert.spy(s1).called_with(mockDto)
                s2:revert()
            end)

            it('supports timeline data', function()
                local s1 = stub(testMatch.api, 'get',function() end)
                testMatch:getById(123456789, {includeTimeline=true})

                assert.stub(s1).called(1)

                local url = {
                    path='/api/lol/${region}/v${version}/match/${matchId}',
                    params={version=testMatch.version,matchId=123456789},
                    query={includeTimeline=true}
                }
                assert.stub(s1).called_with(testMatch.api, lmatch.same(url),lmatch.is_function())
                s1:revert()
            end)

            it('goes to the network to retrieve timeline data if it was not previously requested', function()
                local mockDto = {matchId=123456789}
                local cache = testMatch.api.cache
                local api = testMatch.api

                local s1 = stub(cache, 'get', function() return mockDto end)
                local s2 = stub(api, 'get', function() end)
                testMatch:getById(mockDto.matchId, {callback=function() end,includeTimeline=true})

                assert.stub(s2).called(1)

                s1:revert()
                s2:revert()
            end)
        end)
    end)
end)
