local ui_main_frame = require('ui.main_frame')
local log = require('lib.log')

log.global_min_level = log.level.debug

log:debug('lua version: ' .. _VERSION)

local function init_player(player)
    game.print('init_player, player_index: ' .. player.index)
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
    game.print('init')
    for _, player in pairs(game.players) do
        init_player(player)
    end
    game.print(game.table_to_json(global))
end

local PLAYER_UI = {}

local function update_ui(player_index)
    for _, ui_node in pairs(PLAYER_UI[player_index]) do
        ui_node:update_ui()
    end
end

local function handle_lua_shortcut(event)
    game.print('handle_lua_shortcut')
    game.print(game.table_to_json(event))
    game.print(game.table_to_json(global))
    log:warn('test')

    if not PLAYER_UI[event.player_index] then
        PLAYER_UI[event.player_index] = {}
    end
    local ui_main = PLAYER_UI[event.player_index] and PLAYER_UI[event.player_index].main
    if not ui_main then
        PLAYER_UI[event.player_index].main = ui_main_frame.build(game.players[event.player_index].gui.screen)
    else
        ui_main.data.caption = 'test ' .. game.tick
        update_ui(event.player_index)
    end
end

local function handle_player_create(event)
    game.print('handle_player_created')
    game.print(game.table_to_json(event))
    init_player(game.get_player(event.player_index))
end

local function handle_configuration_change(event)
    game.print('handle_configuration_change')
    game.print(game.table_to_json(event))
    init()
end

script.on_init(init)
script.on_event(defines.events.on_lua_shortcut, handle_lua_shortcut)
script.on_event(defines.events.on_player_created, handle_player_create)
script.on_configuration_changed(handle_configuration_change)
