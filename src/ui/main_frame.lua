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
    local buttun2_enabled = responsive.ref.create(false)

    data = responsive.reactive.create({
        tick = game.tick,
        button1 = {
            tick = responsive.computed.create(function()
                return data.tick
            end)
        },
        button2 = {
            tick = responsive.computed.create(function()
                return data.tick
            end),
            enabled = buttun2_enabled
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
                [':data'] = 'button1',
                [':caption'] = '"button1 " .. tick'
            }, {
                type = 'button',
                [':data'] = 'button2',
                [':caption'] = '"button2 " .. tick',
                [':enabled'] = 'enabled'
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
