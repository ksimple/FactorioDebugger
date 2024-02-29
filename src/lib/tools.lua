local M = {}

M.inherit_prototype = function(source, target)
    target = target or {}

    for k, v in pairs(source) do
        if target[k] == nil then
            target[k] = v
        end
    end

    if getmetatable(source) then
        setmetatable(target, getmetatable(source))
    end

    return target
end

M.table_to_json = function(t)
    return game.table_to_json(t)
end

M.table = {}
M.table.remove = function (t, o)
    local result = {}
    for _, item in ipairs(t) do
        if item ~= o then
            table.insert(result, item)
        end
    end

    return result
end

return M
