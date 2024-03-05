function init_shorcuts(data)
    data:extend({{
        type = 'shortcut',
        name = 'debugger_open_interface',
        action = 'lua',
        toggleable = false,
        order = 'debugger-a[open]',
        associated_control_input = 'debugger_toggle_interface',
        icon = {
            filename = '__debugger__/graphics/shortcut_open_32.png',
            priority = 'extra-high-no-scale',
            size = 32,
            scale = 1,
            flags = {'icon'}
        },
        small_icon = {
            filename = '__debugger__/graphics/shortcut_open_24.png',
            priority = 'extra-high-no-scale',
            size = 24,
            scale = 1,
            flags = {'icon'}
        },
        disabled_small_icon = {
            filename = '__debugger__/graphics/shortcut_open_disabled_24.png',
            priority = 'extra-high-no-scale',
            size = 24,
            scale = 1,
            flags = {'icon'}
        }
    }})
end

---@diagnostic disable-next-line: undefined-global
init_shorcuts(data)
