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
        text = '',
        onclick = function()
            data.enabled = not data.enabled
        end,
        enabled = true
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
                type = 'flow',
                direction = 'vertical',
                children = {{
                    type = 'flow',
                    direction = 'vertical',
                    children = {{
                        type = 'button',
                        [':caption'] = '"button1 " .. tick',
                        ['@click'] = 'onclick'
                    }, {
                        type = 'textfield',
                        [':text'] = 'text',
                        enabled = false
                    }}
                }, {
                    type = 'textfield',
                    ['#text'] = 'text',
                    [':enabled'] = 'enabled'
                }}
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
