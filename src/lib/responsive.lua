local unique_id = require('lib.unique_id')
local log = require('lib.log')
local M = {}

local function inherit_prototype(source, target)
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

M.EVNET_LISTENER_MAP = {}
M.EVENT = {
    PROPERTY_READ = 'property_read',
    PROPERTY_CHANGED = 'property_changed'
}

-- #region notifier
M.notifier = {}
M.notifier.METATABLE = {
    __type = 'knotifier'
}
M.notifier.PROTOTYPE = {
    add_listener = function(self, event, handler)
        if not self.__listener[event] then
            self.__listener[event] = {}
        end
        table.insert(self.__listener[event], handler)
        local listener_index = #self.__listener[event]

        return function()
            table.remove(self.__listener[event], listener_index)
        end
    end,
    emit = function(self, sender, event, ...)
        if self.__parent then
            self.__parent:emit(sender, event, ...)
        end

        if self.__listener[event] then
            for _, handler in ipairs(self.__listener[event]) do
                pcall(handler, sender, event, ...)
            end
        end
    end
}
setmetatable(M.notifier.PROTOTYPE, M.notifier.METATABLE)

M.notifier.create = function(parent)
    if parent and getmetatable(parent) ~= M.notifier.METATABLE then
        error('parent must be a notifier')
    end

    return inherit_prototype(M.notifier.PROTOTYPE, {
        __id = unique_id.generate('notifier'),
        __listener = {},
        __parent = parent
    })
end
-- #endregion

-- #region reactive
M.reactive = {}
M.reactive_global_notifier = M.notifier.create()
M.reactive.METATABLE = {
    __type = 'kreactive',
    __index = function(reactive, name)
        if name:sub(1, 2) == '__' then
            return rawget(reactive, name)
        else
            reactive.__notifier:emit(reactive, M.EVENT.PROPERTY_READ, name)
            return rawget(reactive.__property_table, name)
        end
    end,
    __newindex = function(reactive, name, value)
        -- TODO: 如果新的值是一个 table，是否需要转换成一个 reactive
        if name:sub(1, 2) == '__' then
            -- 内置属性不允许修改
            return
        else
            local old_value = rawget(reactive.__property_table, name)
            rawset(reactive.__property_table, name, value)
            reactive.__notifier:emit(reactive, M.EVENT.PROPERTY_CHANGED, name, old_value, value)
        end
    end
}
M.reactive.PROTOTYPE = {}
setmetatable(M.reactive.PROTOTYPE, M.reactive.METATABLE)

M.reactive.create = function(property_table)
    if property_table then
        local new_property_table = {}

        for key, value in pairs(property_table) do
            if type(value) == 'table' then
                new_property_table[key] = M.reactive.create(value)
            else
                new_property_table[key] = value
            end
        end

        property_table = new_property_table
    else
        property_table = {}
    end

    return inherit_prototype(M.reactive.PROTOTYPE, {
        __id = unique_id.generate('reactive'),
        __notifier = M.notifier.create(M.reactive_global_notifier),
        __add_listener = function(self, event, handler)
            return self.__notifier:add_listener(event, handler)
        end,
        __property_table = property_table
    })
end
-- #endregion

-- #region watch
M.watch = {}

M.watch.METATABLE = {
    __type = 'kwatch'
}
M.watch.PROTOTYPE = {
    __watch_dispose_list = {},
    record = function(self)
        self:clear()

        -- 监控所有被读取的属性
        self.__global_event_listener_dispose = M.reactive_global_notifier:add_listener(M.EVENT.PROPERTY_READ,
            function(reactive, event, get_name)
                table.insert(self.__watch_dispose_list,
                    reactive:__add_listener(M.EVENT.PROPERTY_CHANGED, function(_, event, set_name, old_value, new_value)
                        if get_name == set_name then
                            self.__notifier:emit(reactive, M.EVENT.PROPERTY_CHANGED, set_name, old_value, new_value)
                        end
                    end))
            end)
    end,
    stop = function(self)
        if self.__global_event_listener_dispose then
            self.__global_event_listener_dispose()
            self.__global_event_listener_dispose = nil
        end
    end,
    clear = function(self)
        self:stop()

        for _, dispose in ipairs(self.__watch_dispose_list) do
            dispose()
        end
        self.__watch_dispose_list = {}
    end,
    add_listener = function(self, ...)
        self.__notifier:add_listener(...)
    end
}
setmetatable(M.watch.PROTOTYPE, M.watch.METATABLE)

M.watch.create = function()
    return inherit_prototype(M.watch.PROTOTYPE, {
        __id = unique_id.generate('watch'),
        __notifier = M.notifier.create()
    })
end

-- #endregion

-- #region binding
M.binding = {}

M.binding.METATABLE = {
    __type = 'kbinding'
}
M.binding.PROTOTYPE = {
    __dirty = true,
    __first_get = true,
    __value_cache_valid = false,
    set = function(self, value)
        if self.__mode == M.binding.MODE.PULL or self.__mode == M.binding.MODE.ONE_TIME then
            error('not supported')
        end
        local func = load('local __value = ...; ' .. self.__expression .. ' = __value', nil, 't', self.__data)

        ---@diagnostic disable-next-line: param-type-mismatch
        local status, result = pcall(func, value)
        self:set_dirty(false)
        self.__value_cache_valid = false

        if status then
            return result
        else
            error(result)
        end
    end,
    get = function(self)
        local get = load('return ' .. self.__expression)
        if self.__value_cache_valid then
            return self.__value_cache_value
        end

        if self.__first_get then
            self.__watch:add_listener(M.EVENT.PROPERTY_CHANGED, function(_, _, _, _, _)
                self:set_dirty(true)
                self.__value_cache_valid = false
                self.__value_cache_value = nil
            end)
        end

        -- 释放所有之前监控的属性
        self.__watch:clear()

        if self.__mode ~= M.binding.MODE.ONE_TIME then
            -- 监控所有被读取的属性
            self.__watch:record()
        end

        local func = load('return ' .. self.__expression, nil, 't', self.__data)

        ---@diagnostic disable-next-line: param-type-mismatch, redefined-local
        local status, value = pcall(func)

        self.__watch:stop()

        if status then
            self.__value_cache_valid = true
            self.__value_cache_value = value
            return self.__value_cache_value
        else
            self.__value_cache_valid = false
            self.__value_cache_result = nil
            error(value)
        end
    end,
    dirty = function(self)
        return self.__dirty
    end,
    set_dirty = function(self, value)
        self.__dirty = value
    end,
    dispose = function(self)
        if self.__watch then
            self.__watch:dispose()
        end
    end
}
setmetatable(M.binding.PROTOTYPE, M.binding.METATABLE)

M.binding.MODE = {
    PULL_AND_PUSH = 'pull_and_push',
    PULL = 'pull',
    ONE_TIME = 'one_time'
}

M.binding.unwrap = function(value)
    if getmetatable(value) == M.binding.METATABLE then
        return value:get()
    else
        return value
    end
end

M.binding.create = function(data, expression, mode)
    mode = mode or M.binding.MODE.PULL

    return inherit_prototype(M.binding.PROTOTYPE, {
        __id = unique_id.generate('binding'),
        __data = data,
        __expression = expression,
        __mode = mode,
        __watch = M.watch.create()
    })
end

-- #endregion

-- #region execution

M.execution = {}

M.execution.create = function(process, dirty, dispose, tag)
    local execution = {
        __id = unique_id.generate('execution'),
        dirty = dirty,
        process = process,
        dispose = dispose,
        tag = tag
    }

    return execution
end

M.execution.binding_execution = {
    dirty = function(self)
        return self.tag.binding:dirty()
    end,
    process = function(self)
        self.tag.process_value_change(M.binding.unwrap(self.tag.binding))
        if getmetatable(self.tag.binding) == M.binding.METATABLE then
            self.tag.binding:set_dirty(false)
        end
    end,
    dispose = function(self)
    end
}

M.execution.create_execution_for_binding = function(binding, process_value_change)
    if getmetatable(binding) ~= M.binding.METATABLE then
        error('can only accept binding')
    end
    return M.execution.create(M.execution.binding_execution.process, M.execution.binding_execution.dirty,
        M.execution.binding_execution.dispose, {
            binding = binding,
            process_value_change = process_value_change
        })
end

M.execution.sequence_execution = {
    dirty = function(self)
        for _, execution in ipairs(self.tag.execution_list) do
            if execution:dirty() then
                return true
            end
        end
        return false
    end,
    process = function(self)
        for _, execution in ipairs(self.tag.execution_list) do
            if execution:dirty() then
                execution:process()
            end
        end
    end,
    dispose = function(self)
        for _, execution in ipairs(self.tag.execution_list) do
            execution:dispose()
        end
    end
}

M.execution.create_sequence_execution = function(execution_list)
    return M.execution.create(M.execution.sequence_execution.process, M.execution.sequence_execution.dirty,
        M.execution.sequence_execution.dispose, {
            execution_list = execution_list
        })
end

-- #endregion

return M
