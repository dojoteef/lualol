describe('lol.utils', function()
    local utils
    setup(function()
        utils = require('lol.utils')
    end)

    it('loaded okay', function()
        assert.not_nil(utils)
    end)

    -- note this test will only work on POSIX systems and Windows
    it('correctly gets the epoch time', function()
        local time = os.time()
        assert.is_equal(os.difftime(time, utils.epoch(time)), 0)
    end)
end)

