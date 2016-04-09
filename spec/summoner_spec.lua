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
                local opts = {callback=s1}
                testSummoner:getByName('one', opts)

                assert.stub(s2).called_with(testSummoner, match.same({'one'}), opts)
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
                local s1 = stub(testSummoner.api, 'get',function() end)
                testSummoner:getByNames({'one','two'})

                assert.stub(s1).called(1)

                local url = {
                    path='/api/lol/${region}/v${version}/summoner/by-name/${summonerNames}',
                    params={version=testSummoner.version,summonerNames='one,two'},
                }
                assert.stub(s1).called_with(testSummoner.api, match.same(url),match.is_function())
                s1:revert()
            end)

            local cacheForXSecsFn = function(secs)
                local mockRes = { {one={id=1},two={id=2}}, 200, {}}
                local api = testSummoner.api
                local cache = api.cache
                local cacheSecs = secs or 24*60*60

                local s1 = spy.new(function() end)
                local s2 = stub(cache, 'set')
                local s3 = stub(api, 'get', function(_,_,c) c(unpack(mockRes)) end)
                testSummoner:getByNames({'one','two'}, {callback=s1,expire=secs})

                assert.spy(s1).called(1)
                assert.spy(s1).called_with(unpack(mockRes))

                assert.stub(s2).called(4)
                local cacheKey = {api='summoner',summonerName='one'}
                assert.stub(s2).called_with(cache,match.same(cacheKey),1)

                cacheKey = {api='summoner',summonerId=1}
                assert.stub(s2).called_with(cache,match.same(cacheKey),mockRes[1].one,cacheSecs)

                cacheKey = {api='summoner',summonerName='two'}
                assert.stub(s2).called_with(cache,match.same(cacheKey),2)

                cacheKey = {api='summoner',summonerId=2}
                assert.stub(s2).called_with(cache,match.same(cacheKey),mockRes[1].two,cacheSecs)
                s2:revert()
                s3:revert()
            end

            it('caches api entries for 24 hours by default', function()
                cacheForXSecsFn()
            end)

            it('caches api entries for the specified amount of time', function()
                cacheForXSecsFn(60)
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
                testSummoner:getByNames({'one','two','three'}, {callback=s1}) 

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
                testSummoner:getByNames(names, {callback=s1}) 

                assert.spy(s1).called(3) -- 1st & 2nd for api, 3rd for cache
                assert.spy(s1).called_with(unpack(mockRes1))
                assert.spy(s1).called_with(unpack(mockRes2))
                assert.spy(s1).called_with(match.same({one={id=1},two={id=2}}))

                s2:revert()
                s3:revert()
            end)
        end)

        insulate('getById', function()
            it('calls getByIds with the single id', function()
                local testSummoner = summoner(testApi)
                local s1 = spy.new(function() end)
                local s2 = stub(testSummoner, 'getByIds')
                local opts = {callback=s1}
                testSummoner:getById(123456789, opts)

                assert.stub(s2).called_with(testSummoner, match.same({123456789}), opts)
                s2:revert()
            end)
        end)

        insulate('getByIds', function()
            local testSummoner
            setup(function()
                testSummoner = summoner(testApi)
            end)

            before_each(function()
                testSummoner.api.cache:clearAll()
            end)

            insulate('summoner', function()
                it('uses api get on cache miss', function()
                    local s1 = stub(testSummoner.api, 'get',function() end)
                    testSummoner:getByIds({1,2})

                    assert.stub(s1).called(1)

                    local url = {
                        path='/api/lol/${region}/v${version}/summoner/${summonerIds}${filter}',
                        params={version=testSummoner.version,summonerIds='1,2',filter=''},
                    }
                    assert.stub(s1).called_with(testSummoner.api,match.same(url),match.is_function())
                    s1:revert()
                end)

                local function dataFromRes(res)
                    local data = {{}, res[2], res[3]}
                    for _,v in pairs(res[1]) do
                        data[1][v.name] = v
                    end
                    return data
                end

                local cacheForXSecsFn = function(secs)
                    local mockRes = { {}, 200, {}}
                    mockRes[1]['1']={id=1,name='one'}
                    mockRes[1]['2']={id=2,name='two'}

                    local api = testSummoner.api
                    local cache = api.cache
                    local cacheSecs = secs or 24*60*60

                    local s1 = spy.new(function() end)
                    local s2 = stub(cache, 'set')
                    local s3 = stub(api, 'get', function(_,_,c) c(unpack(mockRes)) end)
                    testSummoner:getByIds({1,2}, {callback=s1,expire=secs})

                    assert.spy(s1).called(1)
                    assert.spy(s1).called_with(unpack(dataFromRes(mockRes)))

                    assert.stub(s2).called(4)
                    local cacheKey = {api='summoner',summonerName='one'}
                    assert.stub(s2).called_with(cache,match.same(cacheKey),1)

                    cacheKey = {api='summoner',summonerId=1}
                    assert.stub(s2).called_with(cache,match.same(cacheKey),mockRes[1]['1'],cacheSecs)

                    cacheKey = {api='summoner',summonerName='two'}
                    assert.stub(s2).called_with(cache,match.same(cacheKey),2)

                    cacheKey = {api='summoner',summonerId=2}
                    assert.stub(s2).called_with(cache,match.same(cacheKey),mockRes[1]['2'],cacheSecs)
                    s2:revert()
                    s3:revert()
                end

                it('caches api entries for 24 hours by default', function()
                    cacheForXSecsFn()
                end)

                it('caches api entries for the specified amount of time', function()
                    cacheForXSecsFn(60)
                end)

                it('will return previously cached entries', function()
                    -- order cache entries back to front
                    local cacheEntries = {{id=2,name='two'},{id=1,name='one'}}
                    local mockRes = {{}, 200, {}}
                    mockRes[1]['3']={id=3,name='three'}

                    local api = testSummoner.api
                    local cache = api.cache

                    local s1 = spy.new(function() end)
                    local s2 = stub(cache, 'get', function()
                        -- table.remove remove last entry first
                        return table.remove(cacheEntries)
                    end)
                    local s3 = stub(api, 'get', function(_,_,c) c(unpack(mockRes)) end)
                    testSummoner:getByIds({1,2,3}, {callback=s1}) 

                    assert.spy(s1).called(2) -- 1st for api, 2nd for cache
                    assert.spy(s1).called_with(unpack(dataFromRes(mockRes)))
                    assert.spy(s1).called_with(match.same({one={id=1,name='one'},two={id=2,name='two'}}))

                    s2:revert()
                    s3:revert()
                end)

                it('will page results', function()
                    -- order cache entries back to front
                    local cacheEntries = {{id=2,name='two'},{id=1,name='one'}}
                    local api = testSummoner.api
                    local cache = api.cache

                    local mockRes1 = {{}, 200, {}}
                    local ids = {1,2}
                    for i = 3, 40 do
                        ids[i] = i
                        local name='summoner'..tostring(i)
                        mockRes1[1][tostring(i)] = {id=i,name=name}
                    end

                    local mockRes2 = {{}, 200, {}}
                    for i = 41,60 do
                        ids[i] = i
                        local name='summoner'..tostring(i)
                        mockRes2[1][name] = {id=i,name=name}
                    end

                    local reslist = {mockRes2,mockRes1}

                    local s1 = spy.new(function() end)
                    local s2 = stub(cache, 'get', function()
                        -- table.remove remove last entry first
                        return table.remove(cacheEntries)
                    end)
                    local s3 = stub(api, 'get', function(_,_,c) c(unpack(table.remove(reslist))) end)
                    testSummoner:getByIds(ids, {callback=s1}) 

                    assert.spy(s1).called(3) -- 1st & 2nd for api, 3rd for cache
                    assert.spy(s1).called_with(unpack(dataFromRes(mockRes1)))
                    assert.spy(s1).called_with(unpack(dataFromRes(mockRes2)))
                    assert.spy(s1).called_with(match.same({one={id=1,name='one'},two={id=2,name='two'}}))

                    s2:revert()
                    s3:revert()
                end)
            end)

            insulate('name', function()
                local filter = 'name'
                it('uses api get on cache miss', function()
                    local s1 = stub(testSummoner.api, 'get',function() end)
                    testSummoner:getByIds({1,2}, {filter=filter})

                    assert.stub(s1).called(1)

                    local url = {
                        path='/api/lol/${region}/v${version}/summoner/${summonerIds}${filter}',
                        params={version=testSummoner.version,summonerIds='1,2',filter='/'..filter},
                    }
                    assert.stub(s1).called_with(testSummoner.api,match.same(url),match.is_function())
                    s1:revert()
                end)

                local function dataFromRes(res)
                    local data = {{}, res[2], res[3]}
                    for idstr,name in pairs(res[1]) do
                        data[1][tonumber(idstr)] = name
                    end
                    return data
                end

                it('caches api entries', function()
                    local mockRes = { {}, 200, {}}
                    mockRes[1]['1']='one'
                    mockRes[1]['2']='two'

                    local api = testSummoner.api
                    local cache = api.cache

                    local s1 = spy.new(function() end)
                    local s2 = stub(cache, 'set')
                    local s3 = stub(api, 'get', function(_,_,c) c(unpack(mockRes)) end)
                    testSummoner:getByIds({1,2}, {callback=s1,filter=filter})

                    assert.spy(s1).called(1)
                    assert.spy(s1).called_with(unpack(dataFromRes(mockRes)))

                    assert.stub(s2).called(2)
                    local cacheKey = {api='summoner',summonerName='one'}
                    assert.stub(s2).called_with(cache,match.same(cacheKey),1)

                    cacheKey = {api='summoner',summonerName='two'}
                    assert.stub(s2).called_with(cache,match.same(cacheKey),2)
                    s2:revert()
                    s3:revert()
                end)

                it('will return previously cached entries', function()
                    -- order cache entries back to front
                    local cacheEntries = {{id=2,name='two'},{id=1,name='one'}}
                    local mockRes = {{}, 200, {}}
                    mockRes[1]['3']='three'

                    local api = testSummoner.api
                    local cache = api.cache

                    local s1 = spy.new(function() end)
                    local s2 = stub(cache, 'get', function()
                        -- table.remove remove last entry first
                        return table.remove(cacheEntries)
                    end)
                    local s3 = stub(api, 'get', function(_,_,c) c(unpack(mockRes)) end)
                    testSummoner:getByIds({1,2,3}, {callback=s1,filter=filter}) 

                    assert.spy(s1).called(2) -- 1st for api, 2nd for cache
                    assert.spy(s1).called_with(unpack(dataFromRes(mockRes)))
                    assert.spy(s1).called_with(match.same({'one','two'}))

                    s2:revert()
                    s3:revert()
                end)
            end)

            insulate('masteries and runes', function()
                local filterTestFn = function(filter)
                    it('uses api get on cache miss', function()
                        local s1 = stub(testSummoner.api, 'get',function() end)
                        testSummoner:getByIds({1,2}, {filter=filter})

                        assert.stub(s1).called(1)

                        local url = {
                            path='/api/lol/${region}/v${version}/summoner/${summonerIds}${filter}',
                            params={version=testSummoner.version,summonerIds='1,2',filter='/'..filter},
                        }
                        assert.stub(s1).called_with(testSummoner.api,match.same(url),match.is_function())
                        s1:revert()
                    end)

                    local function dataFromRes(res)
                        local data = {{}, res[2], res[3]}
                        for idstr,val in pairs(res[1]) do
                            data[1][tonumber(idstr)] = val.pages
                        end
                        return data
                    end

                    local cacheForXSecsFn = function(secs)
                        local mockRes = { {}, 200, {}}
                        mockRes[1]['1']={pages={}}
                        mockRes[1]['2']={pages={}}

                        local api = testSummoner.api
                        local cache = api.cache
                        local cacheSecs = secs or 24*60*60

                        local s1 = spy.new(function() end)
                        local s2 = stub(cache, 'set')
                        local s3 = stub(api, 'get', function(_,_,c) c(unpack(mockRes)) end)
                        testSummoner:getByIds({1,2}, {callback=s1,filter=filter,expire=secs})

                        assert.spy(s1).called(1)
                        assert.spy(s1).called_with(unpack(dataFromRes(mockRes)))

                        assert.stub(s2).called(2)
                        local cacheKey = {api='summoner',data=filter,summonerId=1}
                        assert.stub(s2).called_with(cache,match.same(cacheKey),mockRes[1]['1'].pages,cacheSecs)

                        cacheKey = {api='summoner',data=filter,summonerId=2}
                        assert.stub(s2).called_with(cache,match.same(cacheKey),mockRes[1]['2'].pages,cacheSecs)
                        s2:revert()
                        s3:revert()
                    end

                    it('caches api entries for 24 hours by default', function()
                        cacheForXSecsFn()
                    end)

                    it('caches api entries for the specified amount of time', function()
                        cacheForXSecsFn(60)
                    end)

                    it('will return previously cached entries', function()
                        -- order cache entries back to front
                        local page1 = {}
                        local page2 = {}
                        local cacheEntries = {page2,page1}
                        local mockRes = {{}, 200, {}}
                        mockRes[1]['3']={pages={}}

                        local api = testSummoner.api
                        local cache = api.cache

                        local s1 = spy.new(function() end)
                        local s2 = stub(cache, 'get', function()
                            -- table.remove remove last entry first
                            return table.remove(cacheEntries)
                        end)
                        local s3 = stub(api, 'get', function(_,_,c) c(unpack(mockRes)) end)
                        testSummoner:getByIds({1,2,3}, {callback=s1,filter=filter}) 

                        assert.spy(s1).called(2) -- 1st for api, 2nd for cache
                        assert.spy(s1).called_with(unpack(dataFromRes(mockRes)))
                        assert.spy(s1).called_with(match.same({page1,page2}))

                        s2:revert()
                        s3:revert()
                    end)
                end

                filterTestFn('masteries')
                filterTestFn('runes')
            end)
        end)
    end)
end)
