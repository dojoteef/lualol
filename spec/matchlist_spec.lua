describe('lol.matchlist', function()
    local matchlist
    setup(function()
        matchlist = require('lol.matchlist')
    end)

    it('loaded okay', function()
        assert.not_nil(matchlist)
    end)
end)
