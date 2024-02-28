local tools = require('lib.tools')
local cjson = require('cjson')

local function remove_function(t, processed)
    processed = processed or {}
    local result = {}
    for k, v in pairs(t) do
        if type(v) ~= 'function' then
            if type(v) == 'table' then
                if not processed[v] then
                    processed[v] = true
                    result[k] = remove_function(v, processed)
                    processed[v] = false
                else
                    result[k] = tostring(v)
                end
            else
                result[k] = v
            end
        end
    end
    return result
end

---@diagnostic disable-next-line: duplicate-set-field
tools.table_to_json = function(t)
    return cjson.encode(remove_function(t))
end

local M = {}

--- 单元测试专用方法
--- @param g any
M.set_global = function(g)
    global = g
end

M.set_global({})

M.create_gui_element = function(type)
    local element = {
        type = type,
        style = {},
        children = {}
    }

    element.add = function(parameters)
        local e = M.create_gui_element(parameters.type)
        e.__parent = element
        table.insert(element.children, e)
        e.__index = #element.children
        return e
    end

    element.destroy = function()
        if element.__parent then
            element.__parent.children[element.__index] = nil
        end
    end

    return element
end

return M
