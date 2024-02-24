local M = {}

local function get_tick()
    if game then
        return game.tick
    else
        return 100000000
    end
end

M.generate = function(prefix)
    prefix = prefix or 'none'

    if not global.unique_id then
        global.unique_id = 100000000
    end

    local generated_id = prefix .. '_' .. get_tick() .. '_' .. global.unique_id
    global.unique_id = global.unique_id + 1

    return generated_id
end

return M
