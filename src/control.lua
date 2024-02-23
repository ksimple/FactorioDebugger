local ui_main_frame = require("ui.main_frame")

local function init_player(player)
    game.print("init_player, player_index: " .. player.index)
    if not global.player_map then
        global.player_map = {}
    end
    global.player_map[player.index] = {
        ui = {
            main = nil
        }
    }
end

local function init()
    game.print('lua version: ' .. '_VERSION')
    game.print("init")
    for _, player in pairs(game.players) do
        init_player(player)
    end
    game.print(game.table_to_json(global))
end

local function handle_lua_shortcut(event)
    game.print('lua version: ' .. _VERSION)
    game.print("handle_lua_shortcut")
    game.print(game.table_to_json(event))
    game.print(game.table_to_json(global))
    local ui_main = global.player_map[event.player_index].ui.main
    if ui_main then
        ui_main.destroy()
    end
    if not ui_main or not ui_main.valid then
        global.player_map[event.player_index].ui.main = ui_main_frame.build(game.players[event.player_index].gui.screen)
    end
end

local function handle_player_create(event)
    game.print("handle_player_created")
    game.print(game.table_to_json(event))
    init_player(game.get_player(event.player_index))
end

local function handle_configuration_change(event)
    game.print("handle_configuration_change")
    game.print(game.table_to_json(event))
    init()
end

script.on_init(init)
script.on_event(defines.events.on_lua_shortcut, handle_lua_shortcut)
script.on_event(defines.events.on_player_created, handle_player_create)
script.on_configuration_changed(handle_configuration_change)
