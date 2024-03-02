local ui = require('lib.ui')
local responsive = require('lib.responsive')

local M = {}

M.build = function(parent)
    game.print('main_frame.build')

    local element = parent.add({
        type = 'frame',
        tags = {}
    })

    local data

    data = responsive.reactive.create({
        tick = game.tick,
        button = {
            tick = responsive.computed.create(function()
                return data.tick
            end)
        }
    })

    local vnode = ui.vnode.create({
        data = data,
        template = {
            type = 'frame',
            [':caption'] = '"frame " .. tick',
            style = {
                width = 500,
                height = 400
            },
            children = {{
                type = 'button',
                [':data'] = 'button',
                [':caption'] = '"button " .. tick'
            }}
        }
    })

    vnode:__setup()
    vnode:__mount(element)

    return {
        vnode = vnode,
        data = data
    }
end

return M
