local tools = require('lib.tools')
local cjson = require('cjson')
local log = require('lib.log').get_log('helper')

local function prevent_recursive(t, k, v, context)
    if not context.processed then
        context.processed = {}
    end

    if type(v) == 'table' and not context.processed[v] then
        context.processed[v] = true
        return false, v
    else
        return false, tostring(v)
    end
end

local function remove_function(t, k, v, context)
    if type(v) == 'function' then
        return false, tostring(v)
    end

    return prevent_recursive(t, k, v, context)
end

local M = {}

--- 单元测试专用方法
--- @param g any
M.set_global = function(g)
    global = g
end

M.set_global({})

M.clear_component_factory = function()
    local ui = require('lib.ui')

    ui.component.__component_factory_map = {}
end

M.clone_table = function(t, process, process_context)
    local result = {}
    process_context = process_context or {}

    for k, v in pairs(t) do
        local ignore = true

        if process then
            ignore, v = process(t, k, v, process_context)
        end
        if not ignore then
            if type(v) == 'table' then
                result[k] = M.clone_table(v, process, process_context)
            else
                result[k] = v
            end
        end
    end
    return result
end

M.drop_vnode_ref = function(t, k, v, context)
    if k == '__k_vnode' then
        return true, v
    end
    if type(v) == 'function' then
        return true, v
    end
    if string.sub(k, 1, 2) == '__' then
        return true, v
    end

    return prevent_recursive(t, k, v, context)
end

local global_element_index = 1

M.create_gui_element = function(type, player_index)
    player_index = player_index or 1
    local element = {
        type = type,
        style = {},
        player_index = player_index,
        index = global_element_index,
        children = {}
    }

    global_element_index = global_element_index + 1

    element.add = function(parameters)
        local e = M.create_gui_element(parameters.type, player_index)
        e.__parent = element
        table.insert(element.children, e)
        return e
    end

    element.swap_children = function(index_1, index_2)
        local child_element = element.children[index_1]
        element.children[index_1] = element.children[index_2]
        element.children[index_2] = child_element
    end

    element.destroy = function()
        if element.__parent then
            tools.array.remove_value(element.__parent.children, element)
        end
    end

    return element
end

---@diagnostic disable-next-line: duplicate-set-field
tools.table_to_json = function(t)
    return cjson.encode(M.clone_table(t, remove_function, {}))
end

return M
