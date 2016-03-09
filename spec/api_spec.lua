describe('lol.api', function()
    local api,file,match,path
    local keyfile, cacheDir
    setup(function()
        api = require('lol.api')

        file = require('pl.file')
        match = require('luassert.match')

        keyfile = '.test_keyfile'
        file.write(keyfile,'somerandomapikey')

        cacheDir = '.testCache'
        path = require('pl.path')

        if not path.isdir(cacheDir) then
            path.mkdir(cacheDir)
        end
    end)

    teardown(function()
        file.delete(keyfile)

        if path.isdir(cacheDir) then
            local dir = require('pl.dir')
            dir.rmtree(cacheDir)
        end
    end)

    it('loaded okay', function()
        assert.not_nil(api)
    end)

    it('errors if the keyfile does not exist', function()
        assert.has.errors(function() api('bogus_keyfile') end)
    end)

    it('errors if the region does not exist', function()
        assert.has.errors(function() api(keyfile, 'zz') end)
    end)

    it('errors if the directory does not exist', function()
        assert.has.errors(function() api(keyfile, 'na', 'some random directory') end)
    end)

    describe('api', function()
        it('can be successfully created', function()
            local testApi = api(keyfile, 'na', cacheDir)
            assert.is.not_nil(testApi)
        end)

        it('can be successfully created with options', function()
            local testApi = api(keyfile, 'na', cacheDir, {verbose=true})
            assert.is.not_nil(testApi)
        end)

        describe('validator', function()
            it('errors if it is not a table', function()
                assert.is_false(api.isvalid(''))
            end)

            it('errors if it has no valid metatable', function()
                assert.is_false(api.isvalid({}))
            end)

            it('errors if there is an invalid region', function()
                local testApi = api(keyfile, 'na', cacheDir)
                testApi.region = {}
                assert.is_false(api.isvalid(testApi))
            end)

            describe('empty keyfile', function()
                local empty
                setup(function()
                    empty = 'empty_keyfile'
                    file.write(empty,'')
                end)

                teardown(function()
                    file.delete(empty)
                end)

                it('errors', function()
                    local testApi = api(empty, 'na', cacheDir)
                    assert.is_false(api.isvalid(testApi))
                end)
            end)

            it('gives thumbs up for good api object', function()
                local testApi = api(keyfile, 'na', cacheDir)
                assert.is_true(api.isvalid(testApi))
            end)
        end)

        describe('build url', function()
            local host, testApi
            local url

            setup(function()
                testApi = api(keyfile, 'na', cacheDir)
                host = string.match(testApi.region.host, 'https://(.*)')

                -- use socket.url to parse the url for validation purposes
                url = require('socket.url')
            end)

            it("works with basic endpoint", function()
                local args = {path='/some/endpoint'}
                local urlString = testApi:buildUrlString(args)
                local parsed = url.parse(urlString)

                assert.is_equal(parsed.scheme, 'https')
                assert.is_equal(parsed.host, host)
                assert.is_equal(parsed.path, args.path)
                assert.is_equal(parsed.query, 'api_key='..testApi.key)
            end)

            it("works with a template", function()
                local args = {path='/${b}/${a}',params={a='endpoint',b='some'}}
                local urlString = testApi:buildUrlString(args)
                local parsed = url.parse(urlString)

                assert.is_equal(parsed.scheme, 'https')
                assert.is_equal(parsed.host, host)
                assert.is_equal(parsed.path, '/some/endpoint')
                assert.is_equal(parsed.query, 'api_key='..testApi.key)
            end)

            it("works with a query", function()
                local args = {path='/some/endpoint',query={somekey='somevalue'}}
                local urlString = testApi:buildUrlString(args)
                local parsed = url.parse(urlString)

                assert.is_equal(parsed.scheme, 'https')
                assert.is_equal(parsed.host, host)
                assert.is_equal(parsed.path, '/some/endpoint')

                local tablex = require('pl.tablex')
                local queryString = table.concat(tablex.pairmap(function(k,v) return k..'='..v end, tablex.merge({api_key=testApi.key}, args.query, true)), '&')
                assert.is_equal(parsed.query, queryString)
            end)

            it("puts it all together", function()
                local args = {
                    path='/${b}/${a}',
                    params={a='endpoint',b='some'},
                    query={somekey='somevalue'}
                }
                local urlString = testApi:buildUrlString(args)
                local parsed = url.parse(urlString)

                assert.is_equal(parsed.scheme, 'https')
                assert.is_equal(parsed.host, host)
                assert.is_equal(parsed.path, '/some/endpoint')

                local tablex = require('pl.tablex')
                local queryString = table.concat(tablex.pairmap(function(k,v) return k..'='..v end, tablex.merge({api_key=testApi.key}, args.query, true)), '&')
                assert.is_equal(parsed.query, queryString)
            end)
        end)

        describe('get', function()
            local testApi
            local cjson
            local https, headers, mockRes

            setup(function()
                testApi = api(keyfile, 'na', cacheDir)

                -- we will need url quoting and ability to manipulate json
                cjson = require('cjson')

                -- setup some default headers
                headers = {}
                headers['content-length'] = 0
                headers['content-type'] = 'application/json;charset=utf-8'

                -- mock out https.request
                https = require('ssl.https')
                stub(https, "request", function(_)
                    return unpack(mockRes)
                end)
            end)

            teardown(function()
                https.request:revert()
            end)

            it("can make a get", function()
                mockRes = { '', 200, '', 'HTTP/1.1 200 OK' }

                local args = {path='/some/endpoint'}
                testApi:get(args)

                local expectedUrl = testApi:buildUrlString(args)
                assert.stub(https.request).was.called_with(expectedUrl)
            end)

            it("can make a get with a callback", function()
                local mockDto = {someValue=1}
                mockRes = { cjson.encode(mockDto), 200, headers, 'HTTP/1.1 200 OK' }

                local s = spy.new(function() end)
                testApi:get({path='/some/endpoint'}, s)

                assert.spy(s).was.called_with(match.same(mockDto), mockRes[2], mockRes[3])
            end)

            it("returns nil response on json decode error", function()
                mockRes = { "invalid json", 200, headers, 'HTTP/1.1 200 OK' }

                local s = spy.new(function() end)
                testApi:get({path='/some/endpoint'}, s)

                assert.spy(s).was.called_with(nil, mockRes[2], mockRes[3])
            end)

            it("will accept non-json responses", function()
                local mockDto = "<xml></xml>"
                headers['content-type'] = 'application/xml'
                mockRes = { mockDto, 200, headers, 'HTTP/1.1 200 OK' }

                local s = spy.new(function() end)
                testApi:get({path='/some/endpoint'}, s)

                assert.spy(s).was.called_with(mockDto, mockRes[2], mockRes[3])
            end)
        end)
    end)
end)
