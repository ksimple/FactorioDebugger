local unique_id = require('lib.unique_id')
local log = require('lib.log').get_log('lib.responsive')
local tools = require('lib.tools')
local M = {}

M.EVENT = {
    PROPERTY_READ = 'property_read',
    PROPERTY_CHANGED = 'property_changed'
}

-- #region module functions
M.is_ref = function(t)
    local metatable = getmetatable(t)
    return metatable == M.ref.METATABLE or metatable == M.computed.METATABLE
end

M.unref = function(ref)
    if M.is_ref(ref) then
        return ref.value
    else
        return ref
    end
end

M.setref = function(ref, value)
    if M.is_ref(ref) then
        ref.value = value
        return ref, true
    else
        return value, false
    end
end

M.is_reactive = function(t)
    local metatable = getmetatable(t)
    return metatable == M.ref.METATABLE or metatable == M.computed.METATABLE or metatable == M.reactive.METATABLE
end
-- #endregion

-- #region notifier
M.notifier = {}

M.notifier.REMOVED_HANDLER = 'R'

M.notifier.METATABLE = {
    __type = 'knotifier'
}

M.notifier.PROTOTYPE = {
    __id = tools.volatile.create(function()
        return unique_id.generate('notifier')
    end),
    __listener = tools.volatile.create(function()
        return {}
    end),
    add_listener = function(self, event, handler)
        if not self.__listener[event] then
            self.__listener[event] = {
                handler_map = {},
                handler_id_list = {}
            }
        end
        local handler_id = unique_id.generate('eh')
        table.insert(self.__listener[event].handler_id_list, handler_id)
        self.__listener[event].handler_map[handler_id] = handler

        return function()
            self.__listener[event].handler_map[handler_id] = nil
            tools.array_remove_value(self.__listener[event].handler_id_list, handler_id)
        end
    end,
    emit = function(self, sender, event, ...)
        if self.__parent then
            self.__parent:emit(sender, event, ...)
        end

        if self.__listener[event] then
            for _, handler_id in ipairs(self.__listener[event].handler_id_list) do
                local handler = self.__listener[event].handler_map[handler_id]
                local status, value = pcall(handler, sender, event, ...)

                if not status then
                    log:warn(value)
                end
            end
        end
    end,
    get_listener_count = function(self, event)
        if self.__listener[event] then
            return #self.__listener[event].handler_id_list
        else
            return 0
        end
    end
}
setmetatable(M.notifier.PROTOTYPE, M.notifier.METATABLE)

M.notifier.create = function(parent)
    if parent and getmetatable(parent) ~= M.notifier.METATABLE then
        error('parent must be a notifier')
    end

    return tools.inherit_prototype(M.notifier.PROTOTYPE, {
        __parent = parent
    })
end

M.responsive_global_notifier = M.notifier.create()
-- #endregion

-- #region ref
M.ref = {}

M.ref.METATABLE = {
    __type = 'kref',
    __index = function(self, name)
        if name:sub(1, 2) == '__' then
            return rawget(self, name)
        elseif name == 'value' then
            self.__notifier:emit(self, M.EVENT.PROPERTY_READ, {
                name = name
            })
            return M.unref(rawget(self, '__value'))
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

            value = M.setref(old_value, value)
            if value ~= old_value then
                rawset(self, '__value', value)
            end
            self.__notifier:emit(self, M.EVENT.PROPERTY_CHANGED, {
                name = name,
                value = value
            })
        end
    end
}

M.ref.PROTOTYPE = {
    __id = tools.volatile.create(function()
        return unique_id.generate('ref')
    end),
    __notifier = tools.volatile.create(function()
        return M.notifier.create(M.responsive_global_notifier)
    end),
    __add_listener = function(self, event, handler)
        return self.__notifier:add_listener(event, handler)
    end
}

setmetatable(M.ref.PROTOTYPE, M.ref.METATABLE)

M.ref.create = function(value)
    return tools.inherit_prototype(M.ref.PROTOTYPE, {
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
            self.__notifier:emit(self, M.EVENT.PROPERTY_READ, {
                name = name
            })
            local raw_value = M.unref(rawget(self, '__get')(self))
            rawset(self, '__raw_value', raw_value)
            return raw_value
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
                local old_raw_value = rawget(self, '__raw_value')
                set(self, value)
                local new_raw_value = M.unref(rawget(self, '__get')(self))
                self.__notifier:emit(self, M.EVENT.PROPERTY_CHANGED, {
                    name = name,
                    value = value
                })
            else
                error('set is not supported')
            end
        end
    end
}

M.computed.PROTOTYPE = {
    __id = tools.volatile.create(function()
        return unique_id.generate('computed')
    end),
    __notifier = tools.volatile.create(function()
        return M.notifier.create(M.responsive_global_notifier)
    end),
    __value = nil,
    __add_listener = function(self, event, handler)
        return self.__notifier:add_listener(event, handler)
    end
}

setmetatable(M.computed.PROTOTYPE, M.computed.METATABLE)

M.computed.create = function(get, set)
    return tools.inherit_prototype(M.computed.PROTOTYPE, {
        __set = set,
        __get = get
    })
end
-- #endregion

-- #region reactive
M.reactive = {}

M.reactive.null = {}

M.reactive.METATABLE = {
    __type = 'kreactive',
    __index = function(self, name)
        if type(name) == 'string' and name:sub(1, 2) == '__' then
            return rawget(self, name)
        else
            local value = nil

            if self.__reactive_map[name] then
                value = self.__reactive_map[name]
            else
                if self.__additional_object and self.__additional_object[name] then
                    value = self.__additional_object[name]
                elseif self.__object and self.__object[name] then
                    value = self.__object[name]
                end

                if value == M.reactive.null then
                    value = nil
                end

                if M.is_ref(value) then
                    value = M.unref(value)
                elseif type(value) == 'table' then
                    if getmetatable(value) == nil then
                        value = M.reactive.create(value)
                    end
                    self.__reactive_map[name] = value
                end
            end

            self.__notifier:emit(self, M.EVENT.PROPERTY_READ, {
                name = name
            })
            return value
        end
    end,
    __newindex = function(self, name, value)
        if type(name) == 'string' and tools.string_starts_with(name, '__') then
            -- 内置属性不允许修改
            return
        else
            local set_value = value

            if set_value == nil then
                set_value = M.reactive.null
            end
            if M.is_reactive(self.__object) then
                self.__object[name] = value
            else
                local value, done = M.setref(self.__object[name], value)

                if not done then
                    self.__object[name] = value
                end
            end

            self.__reactive_map[name] = nil
            self.__notifier:emit(self, M.EVENT.PROPERTY_CHANGED, {
                name = name,
                value = value
            })
        end
    end,
    __len = function(self)
        return self.__object and #self.__object or 0
    end,
    __ipairs = function(self)
        local i = 0
        local len = self.__object and #self.__object or 0

        return function()
            i = i + 1
            if i <= len then
                return i, self.__object[i]
            end
        end
    end
}

M.reactive.PROTOTYPE = {
    __id = tools.volatile.create(function()
        return unique_id.generate('reactive')
    end),
    __reactive_map = tools.volatile.create(function()
        return {}
    end),
    __notifier = tools.volatile.create(function()
        return M.notifier.create(M.responsive_global_notifier)
    end),
    __add_listener = function(self, event, handler)
        return self.__notifier:add_listener(event, handler)
    end
}

setmetatable(M.reactive.PROTOTYPE, M.reactive.METATABLE)

M.reactive.create = function(object, additional_object)
    object = object or {}

    if type(object) ~= 'table' then
        error('object must be a table')
    end
    if additional_object and type(additional_object) ~= 'table' then
        error('additional_object must be a table')
    end

    return tools.inherit_prototype(M.reactive.PROTOTYPE, {
        __object = object,
        __additional_object = additional_object
    })
end
-- #endregion

-- #region watch
M.watch = {}

M.watch.METATABLE = {
    __type = 'kwatch'
}
M.watch.PROTOTYPE = {
    __id = tools.volatile.create(function()
        return unique_id.generate('watch')
    end),
    __notifier = tools.volatile.create(function()
        return M.notifier.create()
    end),
    __watch_dispose_list = tools.volatile.create(function()
        return {}
    end),
    record = function(self)
        self:reset()

        -- 监控所有被读取的属性
        self.__global_event_listener_dispose = M.responsive_global_notifier:add_listener(M.EVENT.PROPERTY_READ,
            function(reactive, _, context)
                local get_name = context.name

                if not self.__recorded_reactive_property[reactive.__id] then
                    self.__recorded_reactive_property[reactive.__id] = {}
                end
                if self.__recorded_reactive_property[reactive.__id][get_name] == nil then
                    log:trace(string.format('watch %s detect %s.%s is read', self.__id, reactive.__id, get_name))
                    table.insert(self.__watch_dispose_list,
                        reactive:__add_listener(M.EVENT.PROPERTY_CHANGED, function(_, _, context)
                            local set_name = context.name

                            if get_name == set_name then
                                log:trace(
                                    string.format('watch %s notify %s.%s is changed', self.__id, reactive.__id, set_name))
                                log:trace(string.format('notifier %s', self.__notifier.__id))
                                self.__notifier:emit(reactive, M.EVENT.PROPERTY_CHANGED, {
                                    name = set_name,
                                    value = context.value
                                })
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
    return tools.inherit_prototype(M.watch.PROTOTYPE, {})
end
-- #endregion

-- #region binding
-- TODO: binding 最后获取值的时候是否应该拆包？
M.binding = {}

M.binding.METATABLE = {
    __type = 'kbinding'
}

M.binding.PROTOTYPE = {
    __id = tools.volatile.create(function()
        return unique_id.generate('binding')
    end),
    __watch = tools.volatile.create(function()
        return M.watch.create()
    end),
    __dirty = true,
    __first_get = true,
    __value_cache_valid = false,
    set = function(self, value)
        if self.__mode == M.binding.MODE.PULL or self.__mode == M.binding.MODE.ONE_TIME then
            error('not supported')
        end

        local unref_data = M.unref(self.__data)

        if type(unref_data) ~= 'table' then
            error('data can be table only')
        end

        -- TODO: 这给地方是否需要使用 setref 来设置这个值？
        local func = load('local __value = ...; ' .. self.__expression .. ' = __value', nil, 't', unref_data)

        ---@diagnostic disable-next-line: param-type-mismatch
        local status, result = pcall(func, value)

        if not status then
            log:warn(value)
        end

        self:set_dirty(false)
        self.__value_cache_valid = false

        if status then
            return result
        else
            error(result)
        end
    end,
    get = function(self)
        if self.__value_cache_valid then
            return self.__value_cache_value
        end

        if self.__data == nil and self.__expression == nil then
            self.__value_cache_value = nil
            self.__value_cache_valid = true
            return self.__value_cache_value
        end

        if self.__first_get then
            self.__watch:add_listener(M.EVENT.PROPERTY_CHANGED, function(sender, _, name, _, _)
                log:trace(string.format('binding %s set to dirty due to %s.%s changed', self.__id, sender.__id, name))
                self:set_dirty(true)
                self.__value_cache_valid = false
                self.__value_cache_value = nil
            end)
        end

        if self.__mode ~= M.binding.MODE.ONE_TIME and self.__mode ~= M.binding.MODE.ALWAYS then
            -- 监控所有被读取的属性
            self.__watch:record()
        end

        local unref_data = M.unref(self.__data)

        if type(unref_data) ~= 'table' and self.__expression then
            self.__watch:stop()
            error(string.format('data can be table only, but %s got', type(unref_data)))
        end

        if self.__expression then
            local func = load('local unref = ... ; return unref(' .. self.__expression .. ')', nil, 't', unref_data)

            ---@diagnostic disable-next-line: param-type-mismatch, redefined-local
            local status, value = pcall(func, M.unref)

            if not status then
                log:warn(value)
            end

            self.__watch:stop()

            log:trace(string.format('binding %s watch on %d properties', self.__id, #self.__watch.__watch_dispose_list))

            if status then
                self.__value_cache_valid = true
                self.__value_cache_value = value
                return self.__value_cache_value
            else
                self.__value_cache_valid = false
                self.__value_cache_result = nil
                error(value)
            end
        else
            self.__watch:stop()
            self.__value_cache_valid = true
            self.__value_cache_value = unref_data
            return self.__value_cache_value
        end
    end,
    dirty = function(self)
        if self.__mode == M.binding.MODE.ALWAYS then
            return true
        end
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
    ONE_TIME = 'one_time',
    ALWAYS = 'always'
}

M.binding.create = function(data, expression, mode)
    mode = mode or M.binding.MODE.PULL

    return tools.inherit_prototype(M.binding.PROTOTYPE, {
        __data = data,
        __expression = expression,
        __mode = mode
    })
end

-- #endregion

return M
