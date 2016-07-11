describe('lol.league', function()
    local league,match
    setup(function()
        match = require('luassert.match')
        league = require('lol.league')
    end)

    it('loaded okay', function()
        assert.not_nil(league)
    end)

    it('errors if given an invalid api obj', function()
        assert.has.errors(function() league({}) end)
    end)

    describe('league', function()
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
            local testLeague = league(testApi)
            assert.is.not_nil(testLeague)
        end)

        it('has the correct API version', function()
            local testLeague = league(testApi)
            assert.is_equal(testLeague.version, '2.5')
        end)

        insulate('getBySummonerId', function()
            local testLeague
            setup(function()
                testLeague = league(testApi)
            end)

            it('calls getBySummonerIds', function()
                local s1 = stub(testLeague, 'getBySummonerIds', function() end)
                testLeague:getBySummonerId(123456789, {})

                assert.stub(s1).called(1)
                assert.stub(s1).called_with(testLeague, {123456789}, {})
            end)
        end)

        insulate('getBySummonerIds', function()
            local testLeague
            setup(function()
                testLeague = league(testApi)
            end)

            it('calls getByIds', function()
                local s1 = stub(testLeague, 'getByIds', function() end)
                testLeague:getBySummonerIds({123456789}, {})

                assert.stub(s1).called(1)
                assert.stub(s1).called_with(testLeague, {123456789}, 'summoner', {})
            end)
        end)

        insulate('getByTeamId', function()
            local testLeague
            setup(function()
                testLeague = league(testApi)
            end)

            it('calls getByTeamIds', function()
                local s1 = stub(testLeague, 'getByTeamIds', function() end)
                testLeague:getByTeamId(123456789, {})

                assert.stub(s1).called(1)
                assert.stub(s1).called_with(testLeague, {123456789}, {})
            end)
        end)

        insulate('getByTeamIds', function()
            local testLeague
            setup(function()
                testLeague = league(testApi)
            end)

            it('calls getByIds', function()
                local s1 = stub(testLeague, 'getByIds', function() end)
                testLeague:getByTeamIds({123456789}, {})

                assert.stub(s1).called(1)
                assert.stub(s1).called_with(testLeague, {123456789}, 'team', {})
            end)
        end)

        insulate('getByIds', function()
            local idTypeTestFn = function(idtype)
                local testLeague
                setup(function()
                    testLeague = league(testApi)
                end)

                before_each(function()
                    testLeague.api.cache:clearAll()
                end)

                it('uses api get on cache miss', function()
                    local s1 = stub(testLeague.api, 'get',function() end)
                    testLeague:getByIds({123456789}, idtype)

                    assert.stub(s1).called(1)

                    local url = {
                        path='/api/lol/${region}/v${version}/league/by-${idtype}/${ids}',
                        params={version=testLeague.version,idtype=idtype,ids=123456789},
                    }
                    assert.stub(s1).called_with(testLeague.api, match.same(url), match.is_function())
                    s1:revert()
                end)

                local cacheForXSecsFn = function(secs)
                    local mockTier = 'TIER'
                    local mockQueue = 'QUEUE'
                    local mockId = '123456789'
                    local mockEntry = {{queue=mockQueue,tier=mockTier,playerOrTeamId=mockId}}
                    local mockLeagues = {{queue=mockQueue,tier=mockTier,participantId=mockId,entries={{playerOrTeamId=mockId}}}} 
                    local mockRes = {{[mockId] = mockLeagues}, 200, {}}

                    local api = testLeague.api
                    local cache = api.cache
                    local cacheSecs = secs or 7*24*60*60

                    local s1 = spy.new(function() end)
                    local s2 = stub(cache, 'set')
                    local s3 = stub(api, 'get', function(_,_,c) c(unpack(mockRes)) end)
                    testLeague:getByIds({mockId}, idtype, {callback=s1,expire=secs})

                    assert.spy(s1).called(1)
                    assert.spy(s1).called_with(mockLeagues, 200, {})

                    assert.stub(s2).called(2)

                    --TODO: Fix this test
                    --[[local tablex = require('pl.tablex')
                    local leagueCache = tablex.deepcopy(mockLeagues[1])
                    leagueCache.participantId = nil -- shouldn't cache the participant id so make sure it isn't

                    local leagueCacheKey = {api='league',queue=mockQueue,tier=mockTier}
                    assert.stub(s2).called_with(cache,leagueCacheKey,leagueCache,cacheSecs)]]

                    local cacheKey = {api='league', [idtype..'Id']=mockId}
                    assert.stub(s2).called_with(cache,cacheKey,match.same(mockEntry),cacheSecs)
                    s2:revert()
                    s3:revert()
                end

                it('caches api entries for 1 week by default', function()
                    cacheForXSecsFn()
                end)

                it('caches api entries for the specified amount of time', function()
                    cacheForXSecsFn(60)
                end)

                it('will return previously cached entries', function()
                    local mockTier = 'TIER'
                    local mockQueue = 'QUEUE'
                    local mockId = '123456789'
                    local mockEntry = {{queue=mockQueue,tier=mockTier,playerOrTeamId=mockId}}
                    local mockLeague = {queue=mockQueue,tier=mockTier,entries={{playerOrTeamId=mockId}}}

                    local cache = testLeague.api.cache
                    local s1 = spy.new(function() end)
                    local s2 = stub(cache, 'get', function(_,k) return (k.queue and mockLeague) or (k[idtype..'Id'] and mockEntry) end)
                    testLeague:getByIds({tonumber(mockId)}, idtype, {callback=s1})

                    assert.spy(s1).called(1)
                    assert.spy(s1).called_with({mockLeague})
                    s2:revert()
                end)

                it('will page results', function()
                    -- order cache entries back to front
                    local cacheEntries = {{{queue='QUEUE',tier='TIER',playerOrTeamId='456'}},{{queue='QUEUE',tier='TIER',playerOrTeamId='123'}}}
                    local api = testLeague.api
                    local cache = api.cache

                    local mockData1 = {}
                    local mockRes1 = {{}, 200, {}}
                    local ids = {123,456}
                    for i = 3, 10 do
                        table.insert(ids, i)
                        mockRes1[1][tostring(i)] = {{queue='QUEUE',tier='TIER',entries={{playerOrTeamId=tostring(i)}}}}
                        mockData1[tostring(i)] = {{queue='QUEUE',tier='TIER',playerOrTeamId=tostring(i)}}
                    end

                    local mockData2 = {}
                    local mockRes2 = {{}, 200, {}}
                    for i = 11,20 do
                        table.insert(ids, i)
                        mockRes2[1][tostring(i)] = {{queue='QUEUE',tier='TIER',entries={{playerOrTeamId=tostring(i)}}}}
                        mockData2[tostring(i)] = {{queue='QUEUE',tier='TIER',playerOrTeamId=tostring(i)}}
                    end

                    local reslist = {mockRes2,mockRes1}

                    local s1 = spy.new(function() end)
                    local s2 = stub(cache, 'get', function()
                        -- table.remove removes last entry first
                        return table.remove(cacheEntries)
                    end)
                    local s3 = stub(api, 'get', function(_,_,c) c(unpack(table.remove(reslist))) end)
                    testLeague:getEntryByIds(ids, idtype, {callback=s1}) 

                    assert.spy(s1).called(3) -- 1st & 2nd for api, 3rd for cache
                    assert.spy(s1).called_with(mockData1, mockRes1[2], mockRes1[3])
                    assert.spy(s1).called_with(mockData2, mockRes2[2], mockRes2[3])

                    local cacheRes = {}
                    cacheRes['123'] = {{queue='QUEUE',tier='TIER',playerOrTeamId='123'}}
                    cacheRes['456'] = {{queue='QUEUE',tier='TIER',playerOrTeamId='456'}}
                    assert.spy(s1).called_with(cacheRes)

                    s2:revert()
                    s3:revert()
                end)
            end

            idTypeTestFn('summoner')
            idTypeTestFn('team')
        end)

        insulate('getEntryBySummonerId', function()
            local testLeague
            setup(function()
                testLeague = league(testApi)
            end)

            it('calls getEntryBySummonerIds', function()
                local s1 = stub(testLeague, 'getEntryBySummonerIds', function() end)
                testLeague:getEntryBySummonerId(123456789, {})

                assert.stub(s1).called(1)
                assert.stub(s1).called_with(testLeague, {123456789}, {})
            end)
        end)

        insulate('getEntryBySummonerIds', function()
            local testLeague
            setup(function()
                testLeague = league(testApi)
            end)

            it('calls getEntryByIds', function()
                local s1 = stub(testLeague, 'getEntryByIds', function() end)
                testLeague:getEntryBySummonerIds({123456789}, {})

                assert.stub(s1).called(1)
                assert.stub(s1).called_with(testLeague, {123456789}, 'summoner', {})
            end)
        end)

        insulate('getEntryByTeamId', function()
            local testLeague
            setup(function()
                testLeague = league(testApi)
            end)

            it('calls getEntryByTeamIds', function()
                local s1 = stub(testLeague, 'getEntryByTeamIds', function() end)
                testLeague:getEntryByTeamId(123456789, {})

                assert.stub(s1).called(1)
                assert.stub(s1).called_with(testLeague, {123456789}, {})
            end)
        end)

        insulate('getEntryByTeamIds', function()
            local testLeague
            setup(function()
                testLeague = league(testApi)
            end)

            it('calls getEntryByIds', function()
                local s1 = stub(testLeague, 'getEntryByIds', function() end)
                testLeague:getEntryByTeamIds({123456789}, {})

                assert.stub(s1).called(1)
                assert.stub(s1).called_with(testLeague, {123456789}, 'team', {})
            end)
        end)

        insulate('getEntryByIds', function()
            local idTypeTestFn = function(idtype)
                local testLeague
                setup(function()
                    testLeague = league(testApi)
                end)

                before_each(function()
                    testLeague.api.cache:clearAll()
                end)

                it('uses api get on cache miss', function()
                    local s1 = stub(testLeague.api, 'get',function() end)
                    testLeague:getEntryByIds({123456789}, idtype)

                    assert.stub(s1).called(1)

                    local url = {
                        path='/api/lol/${region}/v${version}/league/by-${idtype}/${ids}/entry',
                        params={version=testLeague.version,idtype=idtype,ids=123456789},
                    }
                    assert.stub(s1).called_with(testLeague.api, match.same(url), match.is_function())
                    s1:revert()
                end)

                local cacheForXSecsFn = function(secs)
                    local mockTier = 'TIER'
                    local mockQueue = 'QUEUE'
                    local mockId = '123456789'

                    local mockLeagueDto = {{queue=mockQueue,tier=mockTier,participantId=mockId,entries={{playerOrTeamId=mockId}}}} 
                    local mockRes = {{[mockId] = mockLeagueDto}, 200, {}}

                    local mockEntry = {{queue=mockQueue,tier=mockTier,playerOrTeamId=mockId}}
                    local mockEntryRes = {}
                    mockEntryRes[mockId] = mockEntry

                    local api = testLeague.api
                    local cache = api.cache
                    local cacheSecs = secs or 7*24*60*60

                    local s1 = spy.new(function() end)
                    local s2 = stub(cache, 'set')
                    local s3 = stub(api, 'get', function(_,_,c) c(unpack(mockRes)) end)
                    testLeague:getEntryByIds({tonumber(mockId)}, idtype, {callback=s1,expire=secs})

                    assert.spy(s1).called(1)
                    assert.spy(s1).called_with(mockEntryRes, 200, {})

                    local cacheKey = {api='league', [idtype..'Id']=mockId}

                    assert.stub(s2).called(1)
                    assert.stub(s2).called_with(cache,cacheKey,match.same(mockEntry),cacheSecs)
                    s2:revert()
                    s3:revert()
                end

                it('caches api entries for 1 week by default', function()
                    cacheForXSecsFn()
                end)

                it('caches api entries for the specified amount of time', function()
                    cacheForXSecsFn(60)
                end)

                it('will return previously cached entries', function()
                    local mockTier = 'TIER'
                    local mockQueue = 'QUEUE'
                    local mockId = '123456789'
                    local mockEntry = {{queue=mockQueue,tier=mockTier,playerOrTeamId=mockId}}

                    local mockCacheRes = {}
                    mockCacheRes[mockId] = mockEntry

                    local cache = testLeague.api.cache
                    local s1 = spy.new(function() end)
                    local s2 = stub(cache, 'get', function() return mockEntry end)
                    testLeague:getEntryByIds({tonumber(mockId)}, idtype, {callback=s1})

                    assert.spy(s1).called(1)
                    assert.spy(s1).called_with(mockCacheRes)
                    s2:revert()
                end)

                it('will page results', function()
                    -- order cache entries back to front
                    local cacheEntries = {{{queue='QUEUE',tier='TIER',playerOrTeamId='456'}},{{queue='QUEUE',tier='TIER',playerOrTeamId='123'}}}
                    local api = testLeague.api
                    local cache = api.cache

                    local mockData1 = {}
                    local mockRes1 = {{}, 200, {}}
                    local ids = {123,456}
                    for i = 3, 10 do
                        table.insert(ids, i)
                        mockRes1[1][tostring(i)] = {{queue='QUEUE',tier='TIER',entries={{playerOrTeamId=tostring(i)}}}}
                        mockData1[tostring(i)] = {{queue='QUEUE',tier='TIER',playerOrTeamId=tostring(i)}}
                    end

                    local mockData2 = {}
                    local mockRes2 = {{}, 200, {}}
                    for i = 11,20 do
                        table.insert(ids, i)
                        mockRes2[1][tostring(i)] = {{queue='QUEUE',tier='TIER',entries={{playerOrTeamId=tostring(i)}}}}
                        mockData2[tostring(i)] = {{queue='QUEUE',tier='TIER',playerOrTeamId=tostring(i)}}
                    end

                    local reslist = {mockRes2,mockRes1}

                    local s1 = spy.new(function() end)
                    local s2 = stub(cache, 'get', function()
                        -- table.remove removes last entry first
                        return table.remove(cacheEntries)
                    end)
                    local s3 = stub(api, 'get', function(_,_,c) c(unpack(table.remove(reslist))) end)
                    testLeague:getEntryByIds(ids, idtype, {callback=s1}) 

                    assert.spy(s1).called(3) -- 1st & 2nd for api, 3rd for cache
                    assert.spy(s1).called_with(mockData1, mockRes1[2], mockRes1[3])
                    assert.spy(s1).called_with(mockData2, mockRes2[2], mockRes2[3])

                    local cacheRes = {}
                    cacheRes['123'] = {{queue='QUEUE',tier='TIER',playerOrTeamId='123'}}
                    cacheRes['456'] = {{queue='QUEUE',tier='TIER',playerOrTeamId='456'}}
                    assert.spy(s1).called_with(cacheRes)

                    s2:revert()
                    s3:revert()
                end)
            end

            idTypeTestFn('summoner')
            idTypeTestFn('team')
        end)

        insulate('getMasterLeague', function()
            local testLeague
            setup(function()
                testLeague = league(testApi)
            end)

            it('calls getLeague', function()
                local s1 = stub(testLeague, 'getLeague', function() end)
                testLeague:getMasterLeague('QUEUE', {})

                assert.stub(s1).called(1)
                assert.stub(s1).called_with(testLeague, 'master', 'QUEUE', {})
            end)
        end)

        insulate('getChallengerLeague', function()
            local testLeague
            setup(function()
                testLeague = league(testApi)
            end)

            it('calls getLeague', function()
                local s1 = stub(testLeague, 'getLeague', function() end)
                testLeague:getChallengerLeague('QUEUE', {})

                assert.stub(s1).called(1)
                assert.stub(s1).called_with(testLeague, 'challenger', 'QUEUE', {})
            end)
        end)

        insulate('getLeague', function()
            local leagueTestFn = function(leagueType)
                local testLeague
                setup(function()
                    testLeague = league(testApi)
                end)

                before_each(function()
                    testLeague.api.cache:clearAll()
                end)

                it('uses api get on cache miss', function()
                    local mockQueue = 'RANKED_SOLO_5x5'
                    local s1 = stub(testLeague.api, 'get',function() end)
                    testLeague:getLeague(leagueType, mockQueue)

                    assert.stub(s1).called(1)

                    local url = {
                        path='/api/lol/${region}/v${version}/league/${league}',
                        params={version=testLeague.version,league=leagueType},
                        query={type=mockQueue}
                    }
                    assert.stub(s1).called_with(testLeague.api, match.same(url), match.is_function())
                    s1:revert()
                end)

                local cacheForXSecsFn = function(secs)
                    local mockQueue = 'RANKED_SOLO_5x5'
                    local mockTier = testLeague.Leagues[leagueType]
                    local mockId = '123456789'
                    local mockRes = {{queue=mockQueue,tier=mockTier,entries={{playerOrTeamId=mockId}}}, 200, {}}

                    local api = testLeague.api
                    local cache = api.cache
                    local cacheSecs = secs or 7*24*60*60

                    local s1 = spy.new(function() end)
                    local s2 = stub(cache, 'set')
                    local s3 = stub(api, 'get', function(_,_,c) c(unpack(mockRes)) end)
                    testLeague:getLeague(leagueType, mockQueue, {callback=s1,expire=secs})

                    assert.spy(s1).called(1)
                    assert.spy(s1).called_with(mockRes[1], 200, {})

                    assert.stub(s2).called(2)

                    --TODO: Fix this test
                    --[[local leagueCacheKey = {api='league',queue=mockQueue,tier=mockTier}
                    assert.stub(s2).called_with(cache,leagueCacheKey,match.same(mockRes[1]),cacheSecs)]]

                    local idtype = testLeague.RankedQueues[mockQueue]
                    local cacheKey = {api='league', [idtype..'Id']=mockId}
                    assert.stub(s2).called_with(cache,cacheKey,{{queue=mockQueue,tier=mockTier,playerOrTeamId=mockId}},cacheSecs)
                    s2:revert()
                    s3:revert()
                end

                it('caches api entries for 1 week by default', function()
                    cacheForXSecsFn()
                end)

                it('caches api entries for the specified amount of time', function()
                    cacheForXSecsFn(60)
                end)

                it('will return previously cached entries', function()
                    local mockQueue = 'RANKED_SOLO_5x5'
                    local mockTier = testLeague.Leagues[leagueType]
                    local mockId = '123456789'
                    local mockLeague = {queue=mockQueue,tier=mockTier,entries={{playerOrTeamId=mockId}}}

                    local cache = testLeague.api.cache
                    local s1 = spy.new(function() end)
                    local s2 = stub(cache, 'get', function() return mockLeague end)
                    testLeague:getLeague(leagueType, mockQueue, {callback=s1})

                    assert.spy(s1).called(1)
                    assert.spy(s1).called_with(mockLeague)
                    s2:revert()
                end)
            end

            leagueTestFn('master')
            leagueTestFn('challenger')
        end)
    end)
end)
