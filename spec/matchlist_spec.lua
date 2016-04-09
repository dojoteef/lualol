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
                local s1 = stub(testML.api, 'get',function() end)
                testML:getBySummonerId(123456789)

                assert.stub(s1).called(1)

                local url = {
                    path='/api/lol/${region}/v${version}/matchlist/by-summoner/${summonerId}',
                    params={version=testML.version,summonerId=123456789},
                    query={}
                }
                assert.stub(s1).called_with(testML.api, match.same(url), match.is_function())
                s1:revert()
            end)

            local cacheForXSecsFn = function(secs)
                local mockRes = {{summonerId=123456789}, 200, {}}

                local api = testML.api
                local cache = api.cache
                local cacheSecs = secs or 60*60

                local s1 = spy.new(function() end)
                local s2 = stub(cache, 'set')
                local s3 = stub(api, 'get', function(_,_,c) c(unpack(mockRes)) end)
                testML:getBySummonerId(123456789, {callback=s1,expire=secs})

                assert.spy(s1).called(1)
                assert.spy(s1).called_with(unpack(mockRes))

                local cacheKey = {api='matchlist',summonerId=123456789,query={}}
                assert.stub(s2).called_with(cache,match.same(cacheKey),mockRes[1],cacheSecs)
                s2:revert()
                s3:revert()
            end

            it('caches api entries for 1 hour by default', function()
                cacheForXSecsFn()
            end)

            it('caches api entries for the specified amount of time', function()
                cacheForXSecsFn(60)
            end)

            it('will return previously cached entries', function()
                local mockDto = {summonerId=123456789}
                local cache = testML.api.cache
                local s1 = spy.new(function() end)
                local s2 = stub(cache, 'get', function() return mockDto end)
                testML:getBySummonerId(mockDto.summonerId, {callback=s1})

                assert.spy(s1).called(1)
                assert.spy(s1).called_with(mockDto)
                s2:revert()
            end)

            insulate('filters', function()
                it('validates championIds correctly', function()
                    assert.is_false(testML.validateFilters({championIds=''}))
                    assert.is_false(testML.validateFilters({championIds={''}}))
                    assert.is_true(testML.validateFilters({championIds={1}}))
                end)

                it('validates rankedQueues correctly', function()
                    assert.is_false(testML.validateFilters({rankedQueues=1}))
                    assert.is_false(testML.validateFilters({rankedQueues={1}}))
                    assert.is_false(testML.validateFilters({rankedQueues={'somerandomqueue'}}))

                    local validQueue,_ = next(testML.RankedQueues)
                    assert.is_true(testML.validateFilters({rankedQueues={validQueue}}))
                end)

                it('validates seasons correctly', function()
                    assert.is_false(testML.validateFilters({seasons=1}))
                    assert.is_false(testML.validateFilters({seasons={1}}))
                    assert.is_false(testML.validateFilters({seasons={'somerandomqueue'}}))

                    local validSeason,_ = next(testML.Seasons)
                    assert.is_true(testML.validateFilters({seasons={validSeason}}))
                end)

                it('validates indices correctly', function()
                    assert.is_false(testML.validateFilters({beginIndex='1'}))
                    assert.is_false(testML.validateFilters({endIndex='1'}))

                    local filters = {beginIndex=1}
                    assert.is_true(testML.validateFilters(filters))
                    assert.is_same(filters, {beginIndex=1})

                    filters = {endIndex=1}
                    assert.is_true(testML.validateFilters(filters))
                    assert.is_same(filters, {beginIndex=0,endIndex=1})

                    filters = {beginIndex=10,endIndex=1}
                    assert.is_true(testML.validateFilters(filters))
                    assert.is_same(filters, {beginIndex=1,endIndex=10})
                end)

                it('validates time correctly', function()
                    assert.is_false(testML.validateFilters({beginTime='1'}))
                    assert.is_false(testML.validateFilters({endTime='1'}))

                    local mockTime = os.time()
                    local origTimeFn = os.time
                    local utils = require('lol.utils')
                    local s = stub(os, 'time', function(d) return d and origTimeFn(d) or mockTime end)

                    local filters = {beginTime=10}
                    assert.is_true(testML.validateFilters(filters))
                    assert.is_same(filters, {beginTime=10,endTime=utils.epoch()})

                    filters = {endTime=1}
                    assert.is_true(testML.validateFilters(filters))
                    assert.is_same(filters, {beginTime=0,endTime=1})

                    filters = {beginTime=10,endTime=1}
                    assert.is_true(testML.validateFilters(filters))
                    assert.is_same(filters, {beginTime=1,endTime=10})

                    s:revert()
                end)

                it('builds queries correctly', function()
                    assert.has.errors(function() testML.buildQuery({beginTime='huh'}) end)

                    local filters = {championIds={123,456}}
                    local expectedQuery = {championIds='123,456'}
                    assert.is_same(testML.buildQuery(filters), expectedQuery)

                    local queue1 = next(testML.RankedQueues)
                    local queue2 = next(testML.RankedQueues, queue1)
                    filters.rankedQueues = {queue1,queue2}
                    expectedQuery.rankedQueues = queue1..','..queue2
                    assert.is_same(testML.buildQuery(filters), expectedQuery)

                    local season1 = next(testML.Seasons)
                    local season2 = next(testML.Seasons, season1)
                    filters.seasons = {season1,season2}
                    expectedQuery.seasons = season1..','..season2
                    assert.is_same(testML.buildQuery(filters), expectedQuery)

                    filters.beginIndex = 10
                    expectedQuery.beginIndex = 10
                    filters.endIndex = 20
                    expectedQuery.endIndex = 20
                    filters.beginTime = 30
                    expectedQuery.beginTime = 30
                    filters.endTime = 40
                    expectedQuery.endTime = 40
                    assert.is_same(testML.buildQuery(filters), expectedQuery)
                end)
            end)
        end)
    end)
end)
