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

    if t == nil then
        return ''
    end

    return game.table_to_json(M.clone_table(t, remove_function, {}))
end

M.table = {}
M.table.remove = function(t, o)
    local result = {}
    for _, item in ipairs(t) do
        if item ~= o then
            table.insert(result, item)
        end
    end

    return result
end

return M
