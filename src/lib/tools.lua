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

return M
