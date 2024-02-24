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

local message_cache = {}

M.__log = function(level, message)
    -- 跳过不满足输出条件的日志
    if M.level_num[level] < M.level_num[M.global_min_level] then
        return
    end

    local time_or_tick = '<none>'

    if os then
        ---@diagnostic disable-next-line: cast-local-type
        time_or_tick = os.date("%Y-%m-%dT%H:%M:%SZ")
    elseif game then
        time_or_tick = game.tick
    end

    -- TODO: 单人游戏直接打印消息，多人游戏只给 admin 打印消息或者某个指定的玩家？
    if M.in_game then
        if game then
            for _, cached_message in ipairs(message_cache) do
                game.print(cached_message)
            end
            game.print(time_or_tick .. ' [' .. level .. '] ' .. message)
        else
            table.insert(message_cache, time_or_tick .. ' [' .. level .. '] ' .. message)
        end
    else
        print(time_or_tick .. ' [' .. level .. '] ' .. message)
    end
end

M.flush_message_cache = function()
    -- TODO: 单人游戏直接打印消息，多人游戏只给 admin 打印消息或者某个指定的玩家？
    if M.in_game then
        if game then
            for _, cached_message in ipairs(message_cache) do
                game.print(cached_message)
            end
        end
    end
end

M.error = function(message)
    M.__log(M.level.error, message)
end

M.warn = function(message)
    M.__log(M.level.warn, message)
end

M.info = function(message)
    M.__log(M.level.info, message)
end

M.debug = function(message)
    M.__log(M.level.debug, message)
end

M.trace = function(message)
    M.__log(M.level.trace, message)
end

return M
