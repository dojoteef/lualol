describe('lol.matchlist', function()
    local matchlist
    setup(function()
        matchlist = require('lol.matchlist')
    end)

    it('loaded okay', function()
        assert.not_nil(matchlist)
    end)
end)

describe('lol.matchlist', function()
    local matchlist,match
    setup(function()
        match = require('luassert.match')
        matchlist = require('lol.matchlist')
    end)

    it('loaded okay', function()
        assert.not_nil(matchlist)
    end)

    it('errors if given an invalid api obj', function()
        assert.has.errors(function() matchlist({}) end)
    end)

    describe('matchlist', function()
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
            local testML = matchlist(testApi)
            assert.is.not_nil(testML)
        end)

        it('has the correct API version', function()
            local testML = matchlist(testApi)
            assert.is_equal(testML.version, '2.2')
        end)

        insulate('getBySummonerId', function()
            local testML
            setup(function()
                testML = matchlist(testApi)
            end)

            before_each(function()
                testML.api.cache:clearAll()
            end)

            it('uses api get on cache miss', function()
                local s1 = spy.new(function() end)
                local s2 = stub(testML.api, 'get',function() s1() end)
                testML:getBySummonerId(123456789, {}, s1)

                assert.spy(s1).called(1)
                assert.stub(s2).called(1)

                local url = {
                    path='/api/lol/${region}/v${version}/matchlist/by-summoner/${summonerId}',
                    params={version=testML.version,summonerId=123456789},
                }
                assert.stub(s2).called_with(testML.api, match.same(url), match.is_function())
                s2:revert()
            end)

            it('caches api entries for 1 hour', function()
                local mockRes = {{summonerId=123456789}, 200, {}}

                local api = testML.api
                local cache = api.cache

                local s1 = spy.new(function() end)
                local s2 = stub(cache, 'set')
                local s3 = stub(api, 'get', function(_,_,c) c(unpack(mockRes)) end)
                testML:getBySummonerId(123456789, {}, s1)

                assert.spy(s1).called(1)
                assert.spy(s1).called_with(unpack(mockRes))

                local cacheKey = {api='matchlist',summonerId=123456789,filters={}}
                assert.stub(s2).called_with(cache,match.same(cacheKey),mockRes[1],60*60)
                s2:revert()
                s3:revert()
            end)

            it('will return previously cached entries', function()
                local mockDto = {summonerId=123456789}
                local cache = testML.api.cache
                local s1 = spy.new(function() end)
                local s2 = stub(cache, 'get', function() return mockDto end)
                testML:getBySummonerId(mockDto.summonerId, {}, s1)

                assert.spy(s1).called(1)
                assert.spy(s1).called_with(mockDto)
                s2:revert()
            end)
        end)
    end)
end)
