local M = {}
local responsive = require('lib.responsive')
local log = require('lib.log')

M.build_execution_list = function(element, vnode, data, execution_list)
    if vnode.type == 'frame' then
        for _, name in ipairs({'caption'}) do
            if vnode[name] then
                local binding = responsive.binding.create(data, vnode[name], responsive.binding.MODE.PULL)
                local execution = responsive.execution.create_value_execution(binding, function(value)
                    log:debug('设置 ' .. name .. ': ' .. value)
                    element[name] = value
                end)

                table.insert(execution_list, execution)
            end
        end
    end
    if vnode.style then
        for _, name in ipairs({'width', 'height'}) do
            if vnode.style[name] then
                local binding = responsive.binding.create(data, vnode.style[name], responsive.binding.MODE.PULL)
                local execution = responsive.execution.create_value_execution(binding, function(value)
                    log:debug('设置样式 ' .. name .. ': ' .. value)
                    element.style[name] = value
                end)

                table.insert(execution_list, execution)
            end
        end
    end
end

return M
