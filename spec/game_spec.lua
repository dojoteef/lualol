describe('lol.game', function()
    local game
    setup(function()
        game = require('lol.game')
    end)

    it('loaded okay', function()
        assert.not_nil(game)
    end)
end)
