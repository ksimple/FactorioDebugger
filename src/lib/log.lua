local tools = require('lib.tools')
local M = {}

M.level = {
    error = 'error',
    warn = 'warn',
    info = 'info',
    debug = 'debug',
    trace = 'trace'
}

M.level_num = {
    error = 50,
    warn = 40,
    info = 30,
    debug = 20,
    trace = 10
}

M.global_min_level = M.level.warn
M.in_game = true

local log_line_cache = {}

M.__log = function(item)
    local level = item.level or M.level.debug
    -- 跳过不满足输出条件的日志
    if M.level_num[level] < M.level_num[M.global_min_level] then
        return
    end

    local time_or_tick = '<none>'
    local message = item.message
    local module = item.module or ''

    if #module > 20 then
        module = string.sub(module, #module - 20 + 1)
    end

    if type(message) == 'table' then
        message = tools.table_to_json(message)
    elseif message == nil then
        message = '<nil>'
    else
        message = tostring(message)
    end

    if os then
        ---@diagnostic disable-next-line: cast-local-type
        time_or_tick = os.date('%Y-%m-%dT%H:%M:%SZ')
    elseif game then
        time_or_tick = game.tick
    end

    -- local log_line = time_or_tick .. ' [' .. level .. '] ' .. module .. (module ~= '' and ' ' or '') .. '-- ' .. message
    local log_line = string.format("%s [%-5s] %s%s-- %s", time_or_tick, level, module, module ~= '' and ' ' or '',
        message)

    -- TODO: 单人游戏直接打印消息，多人游戏只给 admin 打印消息或者某个指定的玩家？
    if M.in_game then
        if game then
            M.flush_message_cache()
            game.print(log_line)
        else
            table.insert(log_line_cache, log_line)
        end
    else
        print(log_line)
    end
end

M.flush_message_cache = function()
    -- TODO: 单人游戏直接打印消息，多人游戏只给 admin 打印消息或者某个指定的玩家？
    if M.in_game then
        if game then
            for _, cached_message in ipairs(log_line_cache) do
                game.print(cached_message)
            end
            log_line_cache = {}
        end
    end
end

M.output = {}
M.output.METATABLE = {
    __type = 'klog'
}
M.output.PROTOTYPE = {
    error = function(self, message)
        if getmetatable(self) ~= M.output.METATABLE then
            error('use colon to call log method')
        end
        M.__log({
            level = M.level.error,
            module = self.__module,
            message = message
        })
    end,
    warn = function(self, message)
        if getmetatable(self) ~= M.output.METATABLE then
            error('use colon to call log method')
        end
        M.__log({
            level = M.level.warn,
            module = self.__module,
            message = message
        })
    end,
    info = function(self, message)
        if getmetatable(self) ~= M.output.METATABLE then
            error('use colon to call log method')
        end
        M.__log({
            level = M.level.info,
            module = self.__module,
            message = message
        })
    end,
    debug = function(self, message)
        if getmetatable(self) ~= M.output.METATABLE then
            error('use colon to call log method')
        end
        M.__log({
            level = M.level.debug,
            module = self.__module,
            message = message
        })
    end,
    trace = function(self, message)
        if getmetatable(self) ~= M.output.METATABLE then
            error('use colon to call log method')
        end
        M.__log({
            level = M.level.trace,
            module = self.__module,
            message = message
        })
    end
}
setmetatable(M.output.PROTOTYPE, M.output.METATABLE)

M.get_log = function(module)
    return tools.inherit_prototype(M.output.PROTOTYPE, {
        __module = module
    })
end

tools.inherit_prototype(M.output.PROTOTYPE, M)

return M
