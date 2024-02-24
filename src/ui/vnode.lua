local M = {}
local responsive = require('lib.responsive')
local log = require('lib.log')

M.build_execution_plan = function(element, vnode, data, execution_plan)
    if vnode.type == 'frame' then
        for _, name in ipairs({'caption'}) do
            if vnode[name] then
                local execution = responsive.create_visual_execution(data, vnode[name], responsive.BINDING_MODE.PULL,
                    function(value)
                        log.debug('设置 ' .. name .. ': ' .. value)
                        element[name] = value
                    end)

                execution_plan:append(execution)
            end
        end
    end
    if vnode.style then
        for _, name in ipairs({'width', 'height'}) do
            if vnode.style[name] then
                local execution = responsive.create_visual_execution(data, vnode.style[name],
                    responsive.BINDING_MODE.PULL, function(value)
                        log.debug('设置样式 ' .. name .. ': ' .. value)
                        element.style[name] = value
                    end)

                execution_plan:append(execution)
            end
        end
    end
end

return M
