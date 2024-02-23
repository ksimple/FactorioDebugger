local builder = require("ui.builder")

local M = {}

M.build = function(parent)
    game.print("main_frame.build")
    return builder.build(parent, {
        type = "frame",
        style = { 
            width = 500,
            height = 400
        }
    })
end

return M
