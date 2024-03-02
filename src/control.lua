local ui_main_frame = require('ui.main_frame')
local log = require('lib.log')
local tools = require('lib.tools')

log.global_min_level = log.LEVEL.DEBUG
log = log.get_log('control')
log:info('lua version: ' .. _VERSION)

local function init_player(player)
    log:trace('init_player, player_index: ' .. player.index)
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
    log:trace('init')
    for _, player in pairs(game.players) do
        init_player(player)
    end
    log:trace(tools.table_to_json(global))
end

local PLAYER_UI = {}

local function update_ui(player_index)
    for _, ui in pairs(PLAYER_UI[player_index]) do
        ui.vnode:__update_ui()
    end
end

local function handle_lua_shortcut(event)
    log:trace('handle_lua_shortcut')
    log:trace(tools.table_to_json(event))
    log:trace(tools.table_to_json(global))

    if not PLAYER_UI[event.player_index] then
        PLAYER_UI[event.player_index] = {}
    end
    local ui_main = PLAYER_UI[event.player_index] and PLAYER_UI[event.player_index].main
    if not ui_main then
        ui_main = ui_main_frame.build(game.players[event.player_index].gui.screen)
        PLAYER_UI[event.player_index].main = ui_main
    end

    ui_main.data.tick = game.tick
    update_ui(event.player_index)
end

local function handle_player_create(event)
    log:trace('handle_player_created')
    log:trace(tools.table_to_json(event))
    init_player(game.get_player(event.player_index))
end

local function handle_configuration_change(event)
    log:trace('handle_configuration_change')
    log:trace(tools.table_to_json(event))
    init()
end

script.on_init(init)
script.on_event(defines.events.on_lua_shortcut, handle_lua_shortcut)
script.on_event(defines.events.on_player_created, handle_player_create)
script.on_configuration_changed(handle_configuration_change)
