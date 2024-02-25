local tools = require('lib.tools')
local cjson = require('cjson')

local function remove_function(t)
    local result = {}
    for k, v in pairs(t) do
        if type(v) ~= 'function' then
            if type(v) == 'table' then
                result[k] = remove_function(v)
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

return M
