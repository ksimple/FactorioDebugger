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
    local button2_enabled = responsive.ref.create(false)

    data = responsive.reactive.create({
        tick = game.tick,
        text = '',
        button1 = {
            onclick = function()
                button2_enabled.value = not button2_enabled.value
            end
        },
        button2 = {
            enabled = button2_enabled
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
                [':caption'] = '"button1 " .. tick',
                ['@click'] = 'button1.onclick'
            }, {
                type = 'button',
                [':caption'] = 'text',
                [':enabled'] = 'button2.enabled'
            }, {
                type = 'textfield',
                ['#text'] = 'text',
                [':enabled'] = 'button2.enabled'
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
