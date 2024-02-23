local M = {}

M.generate = function(tick, prefix)
    prefix = prefix or 'none'

    if not global.unique_id then
        global.unique_id = 100000000
    end

    local generated_id = prefix .. '_' .. tick .. '_' .. global.unique_id
    global.unique_id = global.unique_id + 1

    return generated_id
end

return M
