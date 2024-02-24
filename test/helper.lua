local M = {}

--- 单元测试专用方法
--- @param g any
M.set_global = function(g)
    global = g
end

M.set_global({})
return M
