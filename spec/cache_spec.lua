describe('lol.cache', function()
    local cache
    setup(function()
        cache = require('lol.cache')
    end)

    it('loaded okay', function()
        assert.is.not_nil(cache)
    end)

    it('errors if the directory does not exist', function()
        assert.has.errors(function() cache('some random directory') end)
    end)

    describe('cache', function()
        local path
        local cacheDir
        setup(function()
            path = require('pl.path')
            cacheDir = '.testCache'

            if not path.isdir(cacheDir) then
                path.mkdir(cacheDir)
            end
        end)

        teardown(function()
            if path.isdir(cacheDir) then
                local dir = require('pl.dir')
                dir.rmtree(cacheDir)
            end
        end)

        it('can be created', function()
            local testCache = cache(cacheDir)
            assert.is.not_nil(testCache)
        end)

        describe('gets and sets', function()
            local testCache
            local origTimeFn, mockTime
            setup(function()
                testCache = cache(cacheDir)

                -- mock out time
                mockTime = os.time()
                origTimeFn = os.time
                stub(os, "time", function(date)
                    return date and origTimeFn(date) or mockTime
                end)
            end)

            teardown(function()
                -- restore time back to the original
                os.time:revert()
            end)

            after_each(function()
                testCache:clearAll()
            end)

            local randomKey = function()
                return 'some key'..tostring(math.random(9999))
            end

            local randomValue = function()
                return 'some value'..tostring(math.random(9999))
            end

            it('can store an entry', function()
                testCache:set(randomKey(), randomValue())

                local tablex = require('pl.tablex')
                assert.is.equal(tablex.size(testCache.cache), 1)
            end)

            it('can retreive an entry', function()
                local key = randomKey()
                local value = randomValue()
                testCache:set(key, value)
                assert.is.equal(testCache:get(key), value)
            end)

            it('can retreive an entry from disk', function()
                local key = randomKey()
                local value = randomValue()
                testCache:set(key, value)

                local testCache2 = cache(testCache.dir)
                assert.is.equal(testCache2:get(key), value)
            end)

            it('properly expires', function()
                local key = randomKey()
                testCache:set(key, randomValue(), -1)
                assert.is_nil(testCache:get(key))
            end)

            it('properly expires', function()
                local expireTime = 60
                testCache:set(randomKey(), randomValue(), expireTime)
                testCache:set(randomKey(), randomValue(), -1)

                local tablex = require('pl.tablex')
                assert.is.equal(tablex.size(testCache.cache), 2)

                testCache:clearExpired()
                assert.is.equal(tablex.size(testCache.cache), 1)

                local dir = require('pl.dir')
                assert.is.equal(tablex.size(dir.getfiles(testCache.dir)), 1)

                mockTime = mockTime + expireTime + 1
                testCache:clearExpired()
                assert.is.equal(tablex.size(testCache.cache), 0)
                assert.is.equal(tablex.size(dir.getfiles(testCache.dir)), 0)
            end)

            it('properly expires directly from disk', function()
                local unexpiredKey = randomKey()
                local unexpiredValue = randomValue()
                testCache:set(unexpiredKey, unexpiredValue)
                testCache:set(randomKey(), randomValue(), -1)

                local tablex = require('pl.tablex')
                assert.is.equal(tablex.size(testCache.cache), 2)

                local testCache2 = cache(testCache.dir)
                testCache2:clearExpired()
                assert.is.equal(testCache2:get(unexpiredKey), unexpiredValue)

                local dir = require('pl.dir')
                assert.is.equal(tablex.size(dir.getfiles(testCache2.dir)), 1)
            end)

            it('properly clears all', function()
                testCache:set(randomKey(), randomValue())
                testCache:set(randomKey(), randomValue())

                local tablex = require('pl.tablex')
                assert.is.equal(tablex.size(testCache.cache), 2)

                testCache:clearAll()
                assert.is.equal(tablex.size(testCache.cache), 0)

                local dir = require('pl.dir')
                assert.is.equal(tablex.size(dir.getfiles(testCache.dir)), 0)
            end)

            it('properly clears all directly from disk', function()
                testCache:set(randomKey(), randomValue())
                testCache:set(randomKey(), randomValue())

                local tablex = require('pl.tablex')
                assert.is.equal(tablex.size(testCache.cache), 2)

                local testCache2 = cache(testCache.dir)
                testCache2:clearAll()
                assert.is.equal(tablex.size(testCache2.cache), 0)

                local dir = require('pl.dir')
                assert.is.equal(tablex.size(dir.getfiles(testCache.dir)), 0)
            end)
        end)
    end)
end)
