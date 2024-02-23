local unique_id = require('lib.unique_id')
local M = {}
local EVNET_LISTENER_MAP = {}

local function add_global_event_listener(event_name, handler)
    if not EVNET_LISTENER_MAP[event_name] then
        EVNET_LISTENER_MAP[event_name] = {}
    end
    table.insert(EVNET_LISTENER_MAP[event_name], handler)
    local listener_index = #EVNET_LISTENER_MAP[event_name]

    return function()
        table.remove(EVNET_LISTENER_MAP[event_name], listener_index)
    end
end

M.EVENT = {
    PROPERTY_READ = 'property_read',
    PROPERTY_CHANGED = 'property_changed'
}

M.create_reactive_table = function(tick)
    local __listener_map = {}
    local special_table = {
        __id = unique_id.generate(tick, "rt"),
        __add_listener = function(event_name, handler)
            if not __listener_map[event_name] then
                __listener_map[event_name] = {}
            end
            table.insert(__listener_map[event_name], handler)
            local listener_index = #__listener_map[event_name]

            return function()
                table.remove(__listener_map[event_name], listener_index)
            end
        end
    }
    local property_table = {}

    local metatable = {
        __index = function(responsive_table, name)
            if name:sub(1, 2) == "__" then
                return special_table[name]
            else
                if EVNET_LISTENER_MAP[M.EVENT.PROPERTY_READ] then
                    for _1, handler in ipairs(EVNET_LISTENER_MAP[M.EVENT.PROPERTY_READ]) do
                        pcall(handler, responsive_table, name)
                    end
                end
                if __listener_map[M.EVENT.PROPERTY_READ] then
                    for _1, handler in ipairs(__listener_map[M.EVENT.PROPERTY_READ]) do
                        pcall(handler, responsive_table, name)
                    end
                end
                return rawget(property_table, name)
            end
        end,
        __newindex = function(responsive_table, name, value)
            if name:sub(1, 2) == "__" then
                return
            else
                local old_value = rawget(property_table, name)
                rawset(property_table, name, value)
                if EVNET_LISTENER_MAP[M.EVENT.PROPERTY_CHANGED] then
                    for _1, handler in ipairs(EVNET_LISTENER_MAP[M.EVENT.PROPERTY_CHANGED]) do
                        pcall(handler, responsive_table, name, old_value, value)
                    end
                end
                if __listener_map[M.EVENT.PROPERTY_CHANGED] then
                    for _1, handler in ipairs(__listener_map[M.EVENT.PROPERTY_CHANGED]) do
                        pcall(handler, responsive_table, name, old_value, value)
                    end
                end
            end
        end
    }

    local raw_table = {}
    setmetatable(raw_table, metatable)

    return raw_table
end

M.BIND_DIRECTION = {
    PULL_AND_PUSH = 'pull_and_push',
    PULL = 'pull'
}

M.create_bind = function(tick, data, expression, direction)
    direction = direction or M.BIND_DIRECTION.PULL

    local dirty = false
    local watch_dispose_list = {}
    local result = {
        __id = unique_id.generate(tick, 'bind'),
        set = nil,
        get = nil,
        dirty = function()
            return dirty
        end,
        set_dirty = function()
            dirty = true
        end,
        clear_dirty = function()
            dirty = false
        end,
        dispose = function()
            for _, dispose in pairs(watch_dispose_list) do
                dispose()
            end
            watch_dispose_list = {}
        end
    }

    if direction == M.BIND_DIRECTION.PULL then
        result.set = function(_)
            error('单推绑定不能设置值')
        end
    else
        result.set = function(value)
            local func = load('local __value = ...; ' .. expression .. ' = __value', nil, "t", data)
            ---@diagnostic disable-next-line: param-type-mismatch
            local status, result = pcall(func, value)

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
    result.get = function()
        if get_cache.valid then
            return get_cache.value
        end

        -- 释放所有之前监控的属性
        for _, dispose in pairs(watch_dispose_list) do
            dispose()
        end
        watch_dispose_list = {}

        local func = load('return ' .. expression, nil, "t", data)

        -- 监控所有被读取的属性
        local dispose = add_global_event_listener(M.EVENT.PROPERTY_READ, function(reactive_table, get_name)
            table.insert(watch_dispose_list,
                reactive_table.__add_listener(M.EVENT.PROPERTY_CHANGED,
                    function(reactive_table, set_name, old_value, new_value)
                        if get_name == set_name and old_value ~= new_value then
                            dirty = true
                            get_cache.valid = false
                            get_cache.value = nil
                        end
                    end))
        end)

        ---@diagnostic disable-next-line: param-type-mismatch, redefined-local
        local status, value = pcall(func)
        dispose()

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

    return result
end

return M
