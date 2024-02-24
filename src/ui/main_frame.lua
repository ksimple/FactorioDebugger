local vnode = require('ui.vnode')
local responsive = require('lib.responsive')

local M = {}

M.build = function(parent)
    game.print('main_frame.build')

    local element = parent.add({
        type = 'frame'
    })
    local execution_plan = responsive.create_execution_plan()
    local data = responsive.create_reactive_table({
        caption = 'test ' .. game.tick,
        width = 500,
        height = 400
    })

    vnode.build_execution_plan(element, {
        type = 'frame',
        caption = 'caption',
        style = {
            width = 'width',
            height = 'height'
        }
    }, data, execution_plan)

    local ui_node = {
        element = element,
        update_ui = function(self)
            if self.execution_plan.dirty() then
                self.execution_plan:execute()
                self.execution_plan:clear_dirty()
            end
        end,
        execution_plan = execution_plan,
        data = data
    }

    ui_node:update_ui()

    return ui_node
end

return M
