describe('lol.summoner', function()
    local summoner
    setup(function()
        summoner = require('lol.summoner')
    end)

    it('loaded okay', function()
        assert.not_nil(summoner)
    end)
end)
describe('lol.summoner', function()
    local summoner,match
    setup(function()
        summoner = require('lol.summoner')
        match = require('luassert.match')
    end)

    it('loaded okay', function()
        assert.not_nil(summoner)
    end)

    it('errors if given an invalid api obj', function()
        assert.has.errors(function() summoner({}) end)
    end)

    describe('summoner', function()
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
            local testSummoner = summoner(testApi)
            assert.is.not_nil(testSummoner)
        end)

        it('has the correct API version', function()
            local testSummoner = summoner(testApi)
            assert.is_equal(testSummoner.version, '1.4')
        end)

        insulate('getByName', function()
            it('calls getByNames with the single name', function()
                local testSummoner = summoner(testApi)
                local s1 = spy.new(function() end)
                local s2 = stub(testSummoner, 'getByNames')
                testSummoner:getByName('one', s1)

                assert.stub(s2).called_with(testSummoner, match.same({'one'}), s1)
                s2:revert()
            end)
        end)

        insulate('getByNames', function()
            local testSummoner
            setup(function()
                testSummoner = summoner(testApi)
            end)

            before_each(function()
                testSummoner.api.cache:clearAll()
            end)

            it('uses api get on cache miss', function()
                local s1 = spy.new(function() end)
                local s2 = stub(testSummoner.api, 'get',function() s1() end)
                testSummoner:getByNames({'one','two'}, s1)

                assert.spy(s1).called(1)
                assert.stub(s2).called(1)

                local url = {
                    path='/api/lol/${region}/v${version}/summoner/by-name/${summonerNames}',
                    params={version=testSummoner.version,summonerNames='one,two'},
                }
                assert.stub(s2).called_with(testSummoner.api, match.same(url),match.is_function())
                s2:revert()
            end)

            it('caches api entries for 24 hours', function()
                local mockRes = { {one={id=1},two={id=2}}, 200, {}}
                local api = testSummoner.api
                local cache = api.cache

                local s1 = spy.new(function() end)
                local s2 = stub(cache, 'set')
                local s3 = stub(api, 'get', function(_,_,c) c(unpack(mockRes)) end)
                testSummoner:getByNames({'one','two'}, s1)

                assert.spy(s1).called(1)
                assert.spy(s1).called_with(unpack(mockRes))

                assert.stub(s2).called(4)
                local cacheKey = {api='summoner',summonerName='one'}
                assert.stub(s2).called_with(cache,match.same(cacheKey),1)

                cacheKey = {api='summoner',summonerId=1}
                assert.stub(s2).called_with(cache,match.same(cacheKey),mockRes[1].one,24*60*60)

                cacheKey = {api='summoner',summonerName='two'}
                assert.stub(s2).called_with(cache,match.same(cacheKey),2)

                cacheKey = {api='summoner',summonerId=2}
                assert.stub(s2).called_with(cache,match.same(cacheKey),mockRes[1].two,24*60*60)
                s2:revert()
                s3:revert()
            end)

            it('will return previously cached entries', function()
                -- order cache entries back to front
                local cacheEntries = {{id=2},2,{id=1},1}
                local mockRes = {{three={id=3}}, 200, {}}
                local api = testSummoner.api
                local cache = api.cache

                local s1 = spy.new(function() end)
                local s2 = stub(cache, 'get', function()
                    -- table.remove remove last entry first
                    return table.remove(cacheEntries)
                end)
                local s3 = stub(api, 'get', function(_,_,c) c(unpack(mockRes)) end)
                testSummoner:getByNames({'one','two','three'}, s1) 

                assert.spy(s1).called(2) -- 1st for api, 2nd for cache
                assert.spy(s1).called_with(unpack(mockRes))
                assert.spy(s1).called_with(match.same({one={id=1},two={id=2}}))

                s2:revert()
                s3:revert()
            end)

            it('will page results', function()
                -- order cache entries back to front
                local cacheEntries = {{id=2},2,{id=1},1}
                local api = testSummoner.api
                local cache = api.cache

                local mockRes1 = {{}, 200, {}}
                local names = {'one','two'}
                for i = 3, 40 do
                    names[i] = 'summoner'..tostring(i)
                    mockRes1[1][names[i]] = {id=i}
                end

                local mockRes2 = {{}, 200, {}}
                for i = 41,60 do
                    names[i] = 'summoner'..tostring(i)
                    mockRes2[1][names[i]] = {id=i}
                end

                local reslist = {mockRes2,mockRes1}

                local s1 = spy.new(function() end)
                local s2 = stub(cache, 'get', function()
                    -- table.remove remove last entry first
                    return table.remove(cacheEntries)
                end)
                local s3 = stub(api, 'get', function(_,_,c) c(unpack(table.remove(reslist))) end)
                testSummoner:getByNames(names, s1) 

                assert.spy(s1).called(3) -- 1st & 2nd for api, 3rd for cache
                assert.spy(s1).called_with(unpack(mockRes1))
                assert.spy(s1).called_with(unpack(mockRes2))
                assert.spy(s1).called_with(match.same({one={id=1},two={id=2}}))

                s2:revert()
                s3:revert()
            end)
        end)
    end)
end)
