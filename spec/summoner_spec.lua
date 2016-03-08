describe('lol.summoner', function()
    local summoner
    setup(function()
        summoner = require('lol.summoner')
    end)

    it('loaded okay', function()
        assert.not_nil(summoner)
    end)
end)
