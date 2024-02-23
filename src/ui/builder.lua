local M = {}

local function build_recursively(parent, data)
    game.print("build_recursively" .. game.table_to_json(data))
    local element = nil
    if data.type == 'frame' then
        element = parent.add{type='frame', caption=data.caption}
        element.style.width = data.style.width
        element.style.height = data.style.height
    end

    return element
end

M.build = function(parent, data)
    game.print("builder.build")
    return build_recursively(parent, data)
end

return M
