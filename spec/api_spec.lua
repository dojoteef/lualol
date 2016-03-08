describe('lol.api', function()
    local api,file,path
    local keyfile, cacheDir
    setup(function()
        api = require('lol.api')

        file = require('pl.file')
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
    end)
end)
