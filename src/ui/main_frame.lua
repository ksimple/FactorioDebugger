local vnode = require('ui.vnode')
local responsive = require('lib.responsive')

local M = {}

M.build = function(parent)
    game.print('main_frame.build')

    local element = parent.add({
        type = 'frame'
    })
    local execution_list = {}
    local data = responsive.reactive.create({
        caption = 'test ' .. game.tick,
        width = 500,
        height = 400
    })

    vnode.build_execution_list(element, {
        type = 'frame',
        caption = 'caption',
        style = {
            width = 'width',
            height = 'height'
        }
    }, data, execution_list)

    local execution = responsive.execution.create_sequence_execution(execution_list)

    local ui_node = {
        element = element,
        update_ui = function(self)
            if self.execution:dirty() then
                self.execution:process()
            end
        end,
        execution = execution,
        data = data
    }

    ui_node:update_ui()

    return ui_node
end

return M
