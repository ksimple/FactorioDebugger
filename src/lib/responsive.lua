local unique_id = require('lib.unique_id')
local M = {}
M.EVNET_LISTENER_MAP = {}

local function add_global_event_listener(event_name, handler)
    if not M.EVNET_LISTENER_MAP[event_name] then
        M.EVNET_LISTENER_MAP[event_name] = {}
    end
    table.insert(M.EVNET_LISTENER_MAP[event_name], handler)
    local listener_index = #M.EVNET_LISTENER_MAP[event_name]

    return function()
        table.remove(M.EVNET_LISTENER_MAP[event_name], listener_index)
    end
end

M.EVENT = {
    PROPERTY_READ = 'property_read',
    PROPERTY_CHANGED = 'property_changed'
}

M.REACTIVE_TABLE_METATABLE = {
    __type = 'kreactive_table',
    __index = function(reactive_table, name)
        if name:sub(1, 2) == "__" then
            return rawget(reactive_table, name)
        else
            if M.EVNET_LISTENER_MAP[M.EVENT.PROPERTY_READ] then
                for _1, handler in ipairs(M.EVNET_LISTENER_MAP[M.EVENT.PROPERTY_READ]) do
                    pcall(handler, reactive_table, name)
                end
            end
            if reactive_table.__listener_map[M.EVENT.PROPERTY_READ] then
                for _1, handler in ipairs(reactive_table.__listener_map[M.EVENT.PROPERTY_READ]) do
                    pcall(handler, reactive_table, name)
                end
            end
            return rawget(reactive_table.__property_table, name)
        end
    end,
    __newindex = function(reactive_table, name, value)
        -- TODO: 如果新的值是一个 table，是否需要转换成一个 reactive_table
        if name:sub(1, 2) == "__" then
            return
        else
            local old_value = rawget(reactive_table.__property_table, name)
            rawset(reactive_table.__property_table, name, value)
            if M.EVNET_LISTENER_MAP[M.EVENT.PROPERTY_CHANGED] then
                for _1, handler in ipairs(M.EVNET_LISTENER_MAP[M.EVENT.PROPERTY_CHANGED]) do
                    pcall(handler, reactive_table, name, old_value, value)
                end
            end
            if reactive_table.__listener_map[M.EVENT.PROPERTY_CHANGED] then
                for _1, handler in ipairs(reactive_table.__listener_map[M.EVENT.PROPERTY_CHANGED]) do
                    pcall(handler, reactive_table, name, old_value, value)
                end
            end
        end
    end
}

M.create_reactive_table = function(property_table)
    if property_table then
        local new_property_table = {}

        for key, value in pairs(property_table) do
            if type(value) == "table" then
                new_property_table[key] = M.create_reactive_table(value)
            else
                new_property_table[key] = value
            end
        end

        property_table = new_property_table
    else
        property_table = {}
    end

    local reactive_table = {
        __id = unique_id.generate("rt"),
        __listener_map = {},
        __add_listener = function(self, event_name, handler)
            if not self.__listener_map[event_name] then
                self.__listener_map[event_name] = {}
            end
            table.insert(self.__listener_map[event_name], handler)
            local listener_index = #self.__listener_map[event_name]

            return function()
                table.remove(self.__listener_map[event_name], listener_index)
            end
        end,
        __property_table = property_table
    }

    setmetatable(reactive_table, M.REACTIVE_TABLE_METATABLE)

    return reactive_table
end

M.BINDING_MODE = {
    PULL_AND_PUSH = 'pull_and_push',
    PULL = 'pull',
    ONE_TIME = 'one_time'
}

M.BINDING_METATABLE = {
    __type = 'kbinding'
}

M.unwrap_binding_value = function(binding)
    if getmetatable(binding) == M.BINDING_METATABLE then
        return binding:get()
    else
        return binding
    end
end

M.create_binding = function(data, expression, mode)
    mode = mode or M.BINDING_MODE.PULL

    local binding = {
        __id = unique_id.generate('bind'),
        __dirty = true,
        __watch_dispose_list = {},
        set = nil,
        get = nil,
        dirty = function(self)
            if self.__dirty then
                return true
            end
            return false
        end,
        set_dirty = function(self)
            self.__dirty = true
        end,
        clear_dirty = function(self)
            self.__dirty = false
        end,
        dispose = function(self)
            for _, dispose in pairs(self.__watch_dispose_list) do
                dispose()
            end
            self.__watch_dispose_list = {}
        end
    }

    if mode == M.BINDING_MODE.PULL or mode == M.BINDING_MODE.ONE_TIME then
        binding.set = function(_, _)
            error('not supported')
        end
    else
        binding.set = function(self, value)
            local func = load('local __value = ...; ' .. expression .. ' = __value', nil, "t",
                M.unwrap_binding_value(data))
            ---@diagnostic disable-next-line: param-type-mismatch
            local status, result = pcall(func, value)
            binding:clear_dirty()

            if status then
                return result
            else
                error(result)
            end
        end
    end

    local get = load('return ' .. expression)

    local get_cache = {
        valid = false,
        value = nil
    }

    binding.get = function(self)
        if get_cache.valid then
            return get_cache.value
        end

        -- 释放所有之前监控的属性
        for _, dispose in pairs(self.__watch_dispose_list) do
            dispose()
        end
        self.__watch_dispose_list = {}

        local dispose

        if mode ~= M.BINDING_MODE.ONE_TIME then
            -- 监控所有被读取的属性
            dispose = add_global_event_listener(M.EVENT.PROPERTY_READ, function(reactive_table, get_name)
                table.insert(self.__watch_dispose_list,
                    reactive_table:__add_listener(M.EVENT.PROPERTY_CHANGED,
                        function(reactive_table, set_name, old_value, new_value)
                            if get_name == set_name and old_value ~= new_value then
                                self:set_dirty()
                                get_cache.valid = false
                                get_cache.value = nil
                            end
                        end))
            end)
        end

        local func = load('return ' .. expression, nil, "t", M.unwrap_binding_value(data))

        ---@diagnostic disable-next-line: param-type-mismatch, redefined-local
        local status, value = pcall(func)

        if dispose then
            dispose()
        end

        if status then
            get_cache.valid = true
            get_cache.value = value
            return get_cache.value
        else
            get_cache.valid = false
            get_cache.result = nil
            error(value)
        end
    end

    setmetatable(binding, M.BINDING_METATABLE)
    return binding
end

M.execution = {}

M.execution.create_execution = function(process, dirty, dispose, tag)
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
        self.tag.process_value_change(M.unwrap_binding_value(self.tag.binding))
        if getmetatable(self.tag.binding) == M.BINDING_METATABLE then
            self.tag.binding:clear_dirty()
        end
    end,
    dispose = function(self)
    end
}

M.execution.create_execution_for_binding = function(binding, process_value_change)
    if getmetatable(binding) ~= M.BINDING_METATABLE then
        error('can only accept binding')
    end
    return M.execution.create_execution(M.execution.binding_execution.process, M.execution.binding_execution.dirty,
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
    return M.execution.create_execution(M.execution.sequence_execution.process, M.execution.sequence_execution.dirty,
        M.execution.sequence_execution.dispose, {
            execution_list = execution_list
        })
end

return M
