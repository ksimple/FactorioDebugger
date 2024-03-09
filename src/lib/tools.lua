local unique_id = require('lib.unique_id')
local log = require('lib.log').get_log('tools')

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
            if getmetatable(v) == M.volatile.METATABLE then
                target[k] = v:get()
            else
                target[k] = v
            end
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

M.string_starts_with = function(str, start)
    return str:sub(1, #start) == start
end

M.array_remove_value = function(t, value)
    for i = #t, 1, -1 do
        if t[i] == value then
            table.remove(t, i)
        end
    end
end

-- #region volatile
M.volatile = {}

M.volatile.METATABLE = {
    __type = "kvolatile"
}

M.volatile.PROTOTYPE = {
    get = function(self)
        return self.__get()
    end
}

setmetatable(M.volatile.PROTOTYPE, M.volatile.METATABLE)

M.volatile.create = function(get)
    return M.inherit_prototype(M.volatile.PROTOTYPE, {
        __id = unique_id.generate('volatile'),
        __get = get
    })
end
-- #endregion

-- #region cacheable
M.cacheable = {}

M.cacheable.METATABLE = {
    __type = "kcacheable"
}

M.cacheable.PROTOTYPE = {
    __cache = nil,
    __valid = false,
    get = function(self)
        if not self.__valid then
            self.__cache = self.__get()
            self.__valid = true
        end

        return self.__cache
    end,
    reset = function(self)
        self.__cache = nil
        self.__valid = false
    end
}

setmetatable(M.cacheable.PROTOTYPE, M.cacheable.METATABLE)

M.cacheable.create = function()
    return M.inherit_prototype(M.cacheable.PROTOTYPE, {
        __id = unique_id.generate('cacheable')
    })
end
-- #endregion

-- #region disposer

M.disposer = {}

M.disposer.METATABLE = {
    __type = "kdispose"
}

M.disposer.PROTOTYPE = {
    add = function(self, dispose_func)
        table.insert(self.__dispose_list, dispose_func)
        local index = #self.__dispose_list

        return function()
            table.remove(self.__dispose_list, index)
        end
    end,

    dispose = function(self)
        for _, dispose_func in ipairs(self.__dispose_list) do
            dispose_func()
        end

        self.__dispose_list = {}
    end
}

setmetatable(M.disposer.PROTOTYPE, M.disposer.METATABLE)

M.disposer.create = function()
    return M.inherit_prototype(M.disposer.PROTOTYPE, {
        __id = unique_id.generate('binding'),
        __dispose_list = {}
    })
end
-- #endregion
return M
