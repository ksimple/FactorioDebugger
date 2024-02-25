local unique_id = require('lib.unique_id')
local log = require('lib.log').get_log('lib.responsive')
local tools = require('lib.tools')
local M = {}

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

    return tools.inherit_prototype(M.notifier.PROTOTYPE, {
        __id = unique_id.generate('notifier'),
        __listener = {},
        __parent = parent
    })
end
-- #endregion

M.responsive_global_notifier = M.notifier.create()

-- #region ref
M.ref = {}
M.ref.METATABLE = {
    __type = 'kref',
    __index = function(self, name)
        if name:sub(1, 2) == '__' then
            return rawget(self, name)
        elseif name == 'value' then
            self.__notifier:emit(self, M.EVENT.PROPERTY_READ, name)
            return rawget(self, '__value')
        else
            return nil
        end
    end,
    __newindex = function(self, name, value)
        if name:sub(1, 2) == '__' then
            -- 内置属性不允许修改
            return
        elseif name == 'value' then
            local old_value = rawget(self, '__value')
            rawset(self, '__value', value)
            self.__notifier:emit(self, M.EVENT.PROPERTY_CHANGED, name, old_value, value)
        end
    end
}
M.ref.PROTOTYPE = {}
setmetatable(M.ref.PROTOTYPE, M.ref.METATABLE)

M.ref.create = function(value)
    return tools.inherit_prototype(M.ref.PROTOTYPE, {
        __id = unique_id.generate('ref'),
        __notifier = M.notifier.create(M.responsive_global_notifier),
        __add_listener = function(self, event, handler)
            return self.__notifier:add_listener(event, handler)
        end,
        __value = value
    })
end
-- #endregion

-- #region computed
M.computed = {}
M.computed.METATABLE = {
    __type = 'kcomputed',
    __index = function(self, name)
        if name:sub(1, 2) == '__' then
            return rawget(self, name)
        elseif name == 'value' then
            self.__notifier:emit(self, M.EVENT.PROPERTY_READ, name)
            local value = rawget(self, '__get')(self)
            rawset(self, '__value', value)
            return value
        else
            return nil
        end
    end,
    __newindex = function(self, name, value)
        if name:sub(1, 2) == '__' then
            -- 内置属性不允许修改
            return
        elseif name == 'value' then
            local set = rawget(self, '__set')

            if set then
                local old_value = rawget(self, '__value')
                set(self, value)
                self.__notifier:emit(self, M.EVENT.PROPERTY_CHANGED, name, old_value, value)
            else
                error('set is not supported')
            end
        end
    end
}
M.computed.PROTOTYPE = {}
setmetatable(M.computed.PROTOTYPE, M.computed.METATABLE)

M.computed.create = function(get, set)
    return tools.inherit_prototype(M.computed.PROTOTYPE, {
        __id = unique_id.generate('computed'),
        __notifier = M.notifier.create(M.responsive_global_notifier),
        __add_listener = function(self, event, handler)
            return self.__notifier:add_listener(event, handler)
        end,
        __set = set,
        __get = get,
        __value = nil
    })
end
-- #endregion

-- #region reactive
M.reactive = {}
M.reactive.METATABLE = {
    __type = 'kreactive',
    __index = function(self, name)
        if name:sub(1, 2) == '__' then
            return rawget(self, name)
        else
            self.__notifier:emit(self, M.EVENT.PROPERTY_READ, name)
            return rawget(self.__raw_table, name)
        end
    end,
    __newindex = function(self, name, value)
        -- TODO: 如果新的值是一个 table，是否需要转换成一个 reactive
        if name:sub(1, 2) == '__' then
            -- 内置属性不允许修改
            return
        else
            local old_value = rawget(self.__raw_table, name)
            rawset(self.__raw_table, name, value)
            self.__notifier:emit(self, M.EVENT.PROPERTY_CHANGED, name, old_value, value)
        end
    end
}
M.reactive.PROTOTYPE = {}
setmetatable(M.reactive.PROTOTYPE, M.reactive.METATABLE)

M.reactive.create = function(raw_table)
    if raw_table and type(raw_table) ~= 'table' then
        error('can only accept table')
    end
    if raw_table then
        local new_raw_table = {}

        for key, value in pairs(raw_table) do
            if type(value) == 'table' then
                new_raw_table[key] = M.reactive.create(value)
            else
                new_raw_table[key] = value
            end
        end

        raw_table = new_raw_table
    else
        raw_table = {}
    end

    return tools.inherit_prototype(M.reactive.PROTOTYPE, {
        __id = unique_id.generate('reactive'),
        __notifier = M.notifier.create(M.responsive_global_notifier),
        __add_listener = function(self, event, handler)
            return self.__notifier:add_listener(event, handler)
        end,
        __raw_table = raw_table
    })
end
-- #endregion

M.unref = function(value)
    if getmetatable(value) == M.ref.METATABLE then
        return value.value
    elseif getmetatable(value) == M.computed.METATABLE then
        return value.value
    else
        return value
    end
end

-- #region watch
M.watch = {}

M.watch.METATABLE = {
    __type = 'kwatch'
}
M.watch.PROTOTYPE = {
    record = function(self)
        self:reset()

        -- 监控所有被读取的属性
        self.__global_event_listener_dispose = M.responsive_global_notifier:add_listener(M.EVENT.PROPERTY_READ,
            function(reactive, _, get_name)
                if not self.__recorded_reactive_property[reactive.__id] then
                    self.__recorded_reactive_property[reactive.__id] = {}
                end
                if self.__recorded_reactive_property[reactive.__id][get_name] == nil then
                    table.insert(self.__watch_dispose_list,
                        reactive:__add_listener(M.EVENT.PROPERTY_CHANGED, function(_, _, set_name, old_value, new_value)
                            if get_name == set_name then
                                self.__notifier:emit(reactive, M.EVENT.PROPERTY_CHANGED, set_name, old_value, new_value)
                            end
                        end))
                    self.__recorded_reactive_property[reactive.__id][get_name] = true
                end
            end)
    end,
    stop = function(self)
        if self.__global_event_listener_dispose then
            self.__global_event_listener_dispose()
            self.__global_event_listener_dispose = nil
        end
    end,
    reset = function(self)
        self:stop()

        if self.__watch_dispose_list then
            for _, dispose in ipairs(self.__watch_dispose_list) do
                dispose()
            end
        end
        self.__watch_dispose_list = {}
        self.__recorded_reactive_property = {}
    end,
    dispose = function(self)
        self:reset()
    end,
    add_listener = function(self, ...)
        self.__notifier:add_listener(...)
    end
}
setmetatable(M.watch.PROTOTYPE, M.watch.METATABLE)

M.watch.create = function()
    return tools.inherit_prototype(M.watch.PROTOTYPE, {
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

        if self.__mode ~= M.binding.MODE.ONE_TIME then
            -- 监控所有被读取的属性
            self.__watch:record()
        end

        local func = load('return ' .. self.__expression, nil, 't', M.unref(self.__data))

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

M.binding.create = function(data, expression, mode)
    mode = mode or M.binding.MODE.PULL

    return tools.inherit_prototype(M.binding.PROTOTYPE, {
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

M.execution.value_execution = {
    dirty = function(self)
        if getmetatable(self.tag.value) == M.binding.METATABLE then
            return self.tag.value:dirty()
        else
            return not self.tag.is_first
        end
    end,
    process = function(self)
        if getmetatable(self.tag.value) == M.binding.METATABLE then
            self.tag.process_value_change(self.tag.value:get())
            self.tag.value:set_dirty(false)
        elseif self.tag.is_first then
            self.tar.process_value_change(self.tag.value)
        end
        self.tag.is_first = false
    end,
    dispose = function(self)
        if getmetatable(self.tag.value) == M.binding.METATABLE then
            self.tag.value:dispose()
        end
    end
}

M.execution.create_value_execution = function(value, process_value_change)
    if getmetatable(value) ~= M.binding.METATABLE then
        error('can only accept binding')
    end
    return M.execution.create(M.execution.value_execution.process, M.execution.value_execution.dirty,
        M.execution.value_execution.dispose, {
            value = value,
            is_first = true,
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
        self.tag.execution_list = {}
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
