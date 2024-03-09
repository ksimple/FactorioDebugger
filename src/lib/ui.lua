local log = require("lib.log").get_log('lib.vnode')
local tools = require('lib.tools')
local unique_id = require('lib.unique_id')
local responsive = require('lib.responsive')

local M = {}

local function handle_gui_event(event)
    M.__process_event(event)

    M.update(event.player_index)
end

M.initialize = function(script)
    script.on_event(defines.events.on_gui_click, handle_gui_event)
    script.on_event(defines.events.on_gui_confirmed, handle_gui_event)

    -- TODO: 其他的事件处理
end

-- TODO: 这个应该是个自动的
M.update = function(player_index)
    for _, vnode in pairs(M.vnode.__root_vnode_map) do
        if vnode.__element.player_index == player_index then
            vnode:__update()
        end
    end
end

M.__process_event = function(event)
    local vnode = M.vnode.get_vnode_by_element(event.element)

    if vnode then
        vnode:__process_event(event)
    end
end

-- #region __property_descriptor_map
-- TODO: 这个类的名字考虑改一下
M.__property_descriptor_map = {}

M.__property_descriptor_map.TYPE = {
    CONST = 'CONST',
    DYNAMIC = 'DYNAMIC',
    MODEL = 'MODEL',
    CALLBACK = 'CALLBACK',
    SLOT = 'SLOT'
}

M.__property_descriptor_map.METATABLE = {
    __type = 'kvtemplate'
}

local prefix_map = {
    [':'] = {
        type = M.__property_descriptor_map.TYPE.DYNAMIC,
        length = 2
    },
    ['v-bind:'] = {
        type = M.__property_descriptor_map.TYPE.DYNAMIC,
        length = 8
    },
    ['v-model:'] = {
        type = M.__property_descriptor_map.TYPE.MODEL,
        length = 9
    },
    ['@'] = {
        type = M.__property_descriptor_map.TYPE.CALLBACK,
        length = 2
    },
    ['v-on:'] = {
        type = M.__property_descriptor_map.TYPE.CALLBACK,
        length = 6
    },
    ['#'] = {
        type = M.__property_descriptor_map.TYPE.SLOT,
        length = 2
    },
    ['v-slot:'] = {
        type = M.__property_descriptor_map.TYPE.SLOT,
        length = 8
    }
}

M.__property_descriptor_map.PROTOTYPE = {
    __id = tools.volatile.create(function()
        return unique_id.generate('template')
    end),
    __descriptor_map = nil,
    __ensure_descriptor_map = function(self)
        local descriptor_map = {}

        for name, value in pairs(self.__template) do
            if not tools.string_starts_with(name, '_') then
                local descriptorType = M.__property_descriptor_map.TYPE.CONST
                local descriptorLength = 0

                for prefix, info in pairs(prefix_map) do
                    if tools.string_starts_with(name, prefix) then
                        descriptorType = info.type
                        descriptorLength = info.length
                        break
                    end
                end

                name = string.sub(name, descriptorLength)

                if descriptor_map[name] then
                    log:warn('duplicate descriptor, name: ' .. name)
                end

                descriptor_map[name] = {
                    type = descriptorType,
                    value = value
                }
            end
        end

        self.__descriptor_map = descriptor_map
    end,
    get_descriptor = function(self, name)
        if not self.__descriptor_map then
            self:__ensure_descriptor_map()
        end

        return self.__descriptor_map[name]
    end,
    get_descriptor_map = function(self)
        return self.__descriptor_map
    end,
    get_template = function(self)
        return self.__template
    end
}

setmetatable(M.__property_descriptor_map.PROTOTYPE, M.__property_descriptor_map.METATABLE)

M.__property_descriptor_map.create = function(template)
    return tools.inherit_prototype(M.__property_descriptor_map.PROTOTYPE, {
        __template = template
    })
end
-- #endregion

-- #region vstyle
M.vstyle = {}

M.vstyle.METATABLE = {
    __type = 'kvstyle',
    __index = function(self, name)
        if string.sub(name, 1, 2) == '__' then
            return rawget(self, name)
        elseif rawget(self, '__get_' .. name) then
            return rawget(self, '__get_' .. name)(self)
        else
            -- TODO: 这里是不是应该直接从 element 上读取？
            return rawget(self, '__property_table')[name]
        end
    end,
    __newindex = function(self, name, value)
        if string.sub(name, 1, 2) == '__' then
            error('not supported, name: ' .. name)
        elseif self['__set_' .. name] then
            self['__set_' .. name](self, value)
        else
            self.__vnode.__element.style[name] = value
            self.__property_table[name] = value
        end
    end
}

M.vstyle.STYLE_PROPERTY_NAME_LIST = {'minimal_width', 'maximal_width', 'minimal_height', 'maximal_height',
                                     'natural_width', 'natural_height', 'top_padding', 'right_padding',
                                     'bottom_padding', 'left_padding', 'top_margin', 'right_margin', 'bottom_margin',
                                     'left_margin', 'horizontal_align', 'vertical_align', 'font_color', 'font',
                                     'top_cell_padding', 'right_cell_padding', 'bottom_cell_padding',
                                     'left_cell_padding', 'horizontally_stretchable', 'vertically_stretchable',
                                     'horizontally_squashable', 'vertically_squashable', 'rich_text_setting',
                                     'hovered_font_color', 'clicked_font_color', 'disabled_font_color',
                                     'pie_progress_color', 'clicked_vertical_offset', 'selected_font_color',
                                     'selected_hovered_font_color', 'selected_clicked_font_color',
                                     'strikethrough_color', 'draw_grayscale_picture', 'horizontal_spacing',
                                     'vertical_spacing', 'use_header_filler', 'bar_width', 'color', 'single_line',
                                     'extra_top_padding_when_activated', 'extra_bottom_padding_when_activated',
                                     'extra_left_padding_when_activated', 'extra_right_padding_when_activated',
                                     'extra_top_margin_when_activated', 'extra_bottom_margin_when_activated',
                                     'extra_left_margin_when_activated', 'extra_right_margin_when_activated',
                                     'stretch_image_to_widget_size', 'badge_font', 'badge_horizontal_spacing',
                                     'default_badge_font_color', 'selected_badge_font_color',
                                     'disabled_badge_font_color', 'width', 'height', 'size', 'padding', 'margin',
                                     'cell_padding', 'extra_padding_when_activated', 'extra_margin_when_activated'}

M.vstyle.PROTOTYPE = {
    __id = tools.volatile.create(function()
        return unique_id.generate('vstyle')
    end),
    __property_table = tools.volatile.create(function()
        return {}
    end),
    __property_execution_list = tools.volatile.create(function()
        return {}
    end),
    __setup = function(self)
        local data = self.__vnode.__data
        local property_execution_list = {}

        if not self.__vnode.__template.style then
            return
        end

        for _, name in ipairs(M.vstyle.STYLE_PROPERTY_NAME_LIST) do
            local descriptor = self.__property_descriptor_map:get_descriptor(name)

            if descriptor then
                if descriptor.type == M.__property_descriptor_map.TYPE.DYNAMIC then
                    local binding = responsive.binding.create(data, descriptor.value, responsive.binding.MODE.PULL)
                    local execution = M.execution.create_value_execution(binding, function(execution, value)
                        log:trace('设置 ' .. name .. ': ' .. value)
                        self[name] = value
                    end)

                    table.insert(property_execution_list, execution)
                elseif descriptor.type == M.__property_descriptor_map.TYPE.CONST then
                    local execution = M.execution.create_value_execution(descriptor.value, function(execution, value)
                        log:trace('设置 ' .. name .. ': ' .. value)
                        self[name] = value
                    end)

                    table.insert(property_execution_list, execution)
                end
            end
        end

        rawset(self, '__property_execution_list', property_execution_list)
    end,
    __update = function(self)
        if self.__property_execution_list then
            for _, execution in ipairs(self.__property_execution_list) do
                if execution:dirty() then
                    execution:process()
                end
            end
        end
    end
}

setmetatable(M.vstyle.PROTOTYPE, M.vstyle.METATABLE)

M.vstyle.create = function(vnode)
    return tools.inherit_prototype(M.vstyle.PROTOTYPE, {
        __vnode = vnode,
        __property_descriptor_map = M.__property_descriptor_map.create(vnode.__template.style)
    })
end
-- #endregion

-- #region execution
-- TODO: 考虑改名字叫 Updater
M.execution = {}

M.execution.create = function(process, dirty, dispose, tag)
    local execution = {
        __id = unique_id.generate('execution'),
        dirty = dirty,
        process = process,
        dispose = dispose,
        tag = tag
    }

    return execution
end

M.execution.value_execution = {
    dirty = function(self)
        if getmetatable(self.tag.value) == responsive.binding.METATABLE then
            return self.tag.value:dirty()
        else
            return self.tag.is_first
        end
    end,
    process = function(self)
        if not self:dirty() then
            return
        end
        if getmetatable(self.tag.value) == responsive.binding.METATABLE then
            self.tag.process_value_change(self, self.tag.value:get())
            self.tag.value:set_dirty(false)
        else
            self.tag.process_value_change(self, self.tag.value)
        end
        self.tag.is_first = false
    end,
    dispose = function(self)
        if getmetatable(self.tag.value) == responsive.binding.METATABLE then
            self.tag.value:dispose()
        end
    end
}

M.execution.create_value_execution = function(value, process_value_change)
    return M.execution.create(M.execution.value_execution.process, M.execution.value_execution.dirty,
        M.execution.value_execution.dispose, {
            value = value,
            is_first = true,
            process_value_change = process_value_change
        })
end
-- #endregion

-- #region vnode
M.vnode = {}

M.vnode.STAGE = {
    SETUP = 'setup',
    MOUNT = 'mount',
    UPDATE = 'update',
    DONE = 'done'
}

M.vnode.METATABLE = {
    __type = 'kvnode',
    __index = function(self, name)
        if string.sub(name, 1, 2) == '__' then
            return rawget(self, name)
        elseif rawget(self, '__get_' .. name) then
            return rawget(self, '__get_' .. name)(self)
        else
            if M.vnode.ELEMENT_PROPERTY_DEFINITION[name] then
                return self.__property_table[name]
            else
                error('property not found: ' .. name)
            end
        end
    end,
    __newindex = function(self, name, value)
        if string.sub(name, 1, 2) == '__' then
            error('not supported, name: ' .. name)
        elseif self['__set_' .. name] then
            self['__set_' .. name](self, value)
        else
            if M.vnode.ELEMENT_PROPERTY_DEFINITION[name] then
                if M.vnode.ELEMENT_PROPERTY_DEFINITION[name].write then
                    self.__element[name] = value
                    self.__property_table[name] = value
                else
                    error('cannot write, name: ' .. name)
                end
            else
                error('property not found: ' .. name)
            end
        end
    end
}

M.vnode.VNODE_TYPE_VIRTUAL = 'virtual'

M.vnode.ELEMENT_PROPERTY_DEFINITION = {
    allow_decimal = {
        read = true,
        write = true
    },
    allow_negative = {
        read = true,
        write = true
    },
    allow_none_state = {
        read = true,
        write = true
    },
    anchor = {
        read = true,
        write = true
    },
    auto_center = {
        read = true,
        write = true
    },
    auto_toggle = {
        read = true,
        write = true
    },
    badge_text = {
        read = true,
        write = true
    },
    caption = {
        read = true,
        write = true
    },
    children_names = {
        read = true,
        write = false
    },
    clicked_sprite = {
        read = true,
        write = true
    },
    clear_and_focus_on_right_click = {
        read = true,
        write = true
    },
    column_count = {
        read = true,
        write = false
    },
    direction = {
        read = true,
        write = false
    },
    drag_target = {
        read = true,
        write = true
    },
    draw_horizontal_line_after_headers = {
        read = true,
        write = true
    },
    draw_horizontal_lines = {
        read = true,
        write = true
    },
    draw_vertical_lines = {
        read = true,
        write = true
    },
    elem_filters = {
        read = true,
        write = true
    },
    elem_tooltip = {
        read = true,
        write = true
    },
    elem_type = {
        read = true,
        write = false
    },
    elem_value = {
        read = true,
        write = true
    },
    enabled = {
        read = true,
        write = true
    },
    entity = {
        read = true,
        write = true
    },
    force = {
        read = true,
        write = true
    },
    game_controller_interaction = {
        read = true,
        write = true
    },
    gui = {
        read = true,
        write = false
    },
    hovered_sprite = {
        read = true,
        write = true
    },
    horizontal_scroll_policy = {
        read = true,
        write = true
    },
    ignored_by_interaction = {
        read = true,
        write = true
    },
    index = {
        read = true,
        write = false
    },
    is_password = {
        read = true,
        write = true
    },
    items = {
        read = true,
        write = true
    },
    left_label_caption = {
        read = true,
        write = true
    },
    left_label_tooltip = {
        read = true,
        write = true
    },
    location = {
        read = true,
        write = true
    },
    locked = {
        read = true,
        write = true
    },
    lose_focus_on_confirm = {
        read = true,
        write = true
    },
    minimap_player_index = {
        read = true,
        write = true
    },
    mouse_button_filter = {
        read = true,
        write = true
    },
    name = {
        read = true,
        write = true
    },
    number = {
        read = true,
        write = true
    },
    object_name = {
        read = true,
        write = false
    },
    parent = {
        read = true,
        write = false
    },
    player_index = {
        read = true,
        write = false
    },
    position = {
        read = true,
        write = true
    },
    raise_hover_events = {
        read = true,
        write = true
    },
    read_only = {
        read = true,
        write = true
    },
    right_label_caption = {
        read = true,
        write = true
    },
    right_label_tooltip = {
        read = true,
        write = true
    },
    selected_index = {
        read = true,
        write = true
    },
    selected_tab_index = {
        read = true,
        write = true
    },
    show_percent_for_small_numbers = {
        read = true,
        write = true
    },
    slider_value = {
        read = true,
        write = true
    },
    sprite = {
        read = true,
        write = true
    },
    state = {
        read = true,
        write = true
    },
    surface_index = {
        read = true,
        write = true
    },
    switch_state = {
        read = true,
        write = true
    },
    tags = {
        read = true,
        write = true
    },
    text = {
        read = true,
        write = true
    },
    toggled = {
        read = true,
        write = true
    },
    tooltip = {
        read = true,
        write = true
    },
    valid = {
        read = true,
        write = false
    },
    value = {
        read = true,
        write = true
    },
    vertical_centering = {
        read = true,
        write = true
    },
    vertical_scroll_policy = {
        read = true,
        write = true
    },
    visible = {
        read = true,
        write = true
    },
    word_wrap = {
        read = true,
        write = true
    },
    zoom = {
        read = true,
        write = true
    }
}

M.vnode.EVENT_MAP = {
    click = true
}

M.vnode.__element_key_to_vnode_map = {}

M.vnode.__root_vnode_map = {}

M.vnode.get_element_key = function(element)
    return string.format('%d_%d', element.player_index, element.index)
end

M.vnode.get_vnode_by_element = function(element)
    local element_key = M.vnode.get_element_key(element)

    return M.vnode.__element_key_to_vnode_map[element_key]
end

M.vnode.PROTOTYPE = {
    __id = tools.volatile.create(function()
        return unique_id.generate('vnode')
    end),
    __disposed = false,
    __binding_descriptor_map = nil,
    __element = nil,
    __property_table = tools.volatile.create(function()
        return {}
    end),
    __binding_set_map = tools.volatile.create(function()
        return {}
    end),
    __property_execution_list = nil,
    __disposer = tools.volatile.create(function()
        return tools.disposer.create()
    end),
    __get_type = function(self)
        return self.__property_descriptor_map and self.__template.type or nil
    end,
    __get_parent_element = function(self)
        if self.__parent_vnode.__element then
            return self.__parent_vnode.__element
        else
            return self.__parent_vnode:__get_parent_element()
        end
    end,
    __get_effective_vnode_list = function(self)
        error('not implemented')
    end,
    __ensure_binding_descriptor_map = function(self)
        local binding_descriptor_map = M.__generate_binding_descriptor_map(self.__property_descriptor_map)

        self.__binding_descriptor_map = binding_descriptor_map
    end,
    __setup = function(self)
        error('not implemented')
    end,
    __mount = function(self, element)
        error('not implemented')
    end,
    __update = function(self)
        error('not implemented')
    end,
    __unmount = function(self)
        error('not implemented')
    end,
    __dispose = function(self)
        error('not implemented')
    end
}

setmetatable(M.vnode.PROTOTYPE, M.vnode.METATABLE)

-- TODO: tab 的特殊处理逻辑
M.vnode.ELEMENT_PROTOTYPE = tools.inherit(M.vnode.PROTOTYPE, {
    -- #region children processing
    __ensure_child_vnode_list = function(self)
        if self.__child_vnode_list then
            return
        end

        local child_vnode_list = {}

        if (self.__template.children) then
            for index, child in ipairs(self.__template.children) do
                child_vnode_list[index] = M.vnode.create({
                    parent = self,
                    template = child,
                    data = self.__data
                })
            end
        end

        rawset(self, '__child_vnode_list', child_vnode_list)
    end,
    __get_effective_vnode_list_binding = function(self)
        return responsive.binding.create({
            data = {self}
        }, 'data', responsive.binding.MODE.ONE_TIME)
    end,
    __create_element = function(self)
        local parent_element = self:__get_parent_element()
        if self.type == 'flow' or self.type == 'frame' then
            return parent_element.add({
                type = self.type,
                direction = (not self.direction and self.direction == 'horizontal') and 'horizontal' or 'vertical'
            })
        else
            return parent_element.add({
                type = self.type
            })
        end
    end,
    __process_effective_child_vnode_list = function(self, effective_child_vnode_list)
        log:trace(string.format('call process_effective_child_vnode_list, vnode: %s, #effective_child_vnode_list: %d',
            self.__id, #effective_child_vnode_list))
        for _, vnode in ipairs(effective_child_vnode_list) do
            if vnode.__stage == M.vnode.STAGE.SETUP then
                vnode:__setup()
            end
        end
        for _, vnode in ipairs(effective_child_vnode_list) do
            if vnode.__stage == M.vnode.STAGE.MOUNT then
                vnode:__mount()
            end
        end

        local vnode_map = {}
        for _, vnode in ipairs(effective_child_vnode_list) do
            vnode_map[vnode.__id] = true
        end

        for _, element in ipairs(self.__element.children) do
            local vnode = M.vnode.get_vnode_by_element(element)

            if not vnode_map[vnode.__id] then
                vnode:__unmount()
                vnode:__dispose()
                element.destroy()
            end
        end

        for index = 1, #self.__element.children do
            local element = self.__element.children[index]
            local vnode = effective_child_vnode_list[index]

            if M.vnode.get_vnode_by_element(element) ~= vnode then
                for index2 = index + 1, #self.__element.children do
                    if self.__element.children[index2] == vnode then
                        self.__element.swap_children(index, index2)
                    end
                end
            end
        end
    end,
    -- #endregion

    __dispose = function(self)
        if self.__stage == M.vnode.STAGE.UPDATE then
            self:__unmount()
        end
        self.__disposer:dispose()
        self.__disposed = true
    end,

    -- #region event handling
    __process_event = function(self, event)
        if event.name == defines.events.on_gui_click then
            self:__invoke_event_handler('click', event)
        elseif event.name == defines.events.on_gui_confirmed then
            -- TODO: 支持双向绑定的后缀 .lazy .number .trim
            if self.__property_binding_map['text'] then
                self.__property_binding_map['text']:set(event.element.text)
            end
            self:__invoke_event_handler('confirmed', event)
        end
    end,
    __invoke_event_handler = function(self, name, event)
        -- TODO: 支持一些事件后缀 .stop .prevent .self .once .passive
        local descriptor = self.__property_descriptor_map:get_descriptor(name)
        local func

        if descriptor and descriptor.type == M.__property_descriptor_map.TYPE.CALLBACK then
            func = load('return ' .. descriptor.value, nil, 't', responsive.unref(self.__data))()
        end

        if func then
            func(self, name, event)
        end
    end,
    -- #endregion

    -- #region stage processing
    __stage = M.vnode.STAGE.SETUP,
    __setup = function(self)
        log:trace(string.format('call setup, vnode: %s', self.__id))
        if self.__stage ~= M.vnode.STAGE.SETUP then
            error('wrong stage, stage: ' .. self.__stage)
        end
        local data = self.__data
        local property_execution_list = {}
        local property_binding_map = {}

        if M.vnode.ELEMENT_TYPE_MAP[self.type] then
            for name, definition in pairs(M.vnode.ELEMENT_PROPERTY_DEFINITION) do
                if definition.write then
                    -- TODO: 增加双向绑定的测试用例

                    local descriptor = self.__property_descriptor_map:get_descriptor(name)

                    if descriptor then
                        if descriptor.type == M.__property_descriptor_map.TYPE.DYNAMIC then
                            -- TODO: 这里除了把 data 传进去当上下文外，是否还应该有个函数定制上下文
                            local binding = responsive.binding.create(data, descriptor.value,
                                responsive.binding.MODE.PULL)
                            local execution = M.execution.create_value_execution(binding, function(execution, value)
                                log:trace('设置 ' .. name .. ': ' .. tostring(value))
                                self[name] = value
                            end)

                            table.insert(property_execution_list, execution)
                        elseif descriptor.type == M.__property_descriptor_map.TYPE.MODEL then
                            -- TODO: 这里除了把 data 传进去当上下文外，是否还应该有个函数定制上下文
                            local binding = responsive.binding.create(data, descriptor.value,
                                responsive.binding.MODE.PULL_AND_PUSH)
                            local execution = M.execution.create_value_execution(binding, function(execution, value)
                                log:trace('设置 ' .. name .. ': ' .. tostring(value))
                                self[name] = value
                            end)

                            table.insert(property_execution_list, execution)
                            property_binding_map[name] = binding
                        elseif descriptor.type == M.__property_descriptor_map.TYPE.CONST then
                            -- TODO: 这里除了把 data 传进去当上下文外，是否还应该有个函数定制上下文
                            local execution = M.execution.create_value_execution(descriptor.value,
                                function(execution, value)
                                    log:trace('设置 ' .. name .. ': ' .. tostring(value))
                                    self[name] = value
                                end)

                            table.insert(property_execution_list, execution)
                        end
                    end
                end
            end
        elseif self.type == M.vnode.VNODE_TYPE_VIRTUAL then
            -- TODO: 重新考虑一下虚节点的使用场景，暂时禁用
            error('virtual is not supported temporarily')
        else
            error('unknown type: ' .. self.type)
        end

        rawset(self, '__property_execution_list', property_execution_list)
        rawset(self, '__property_binding_map', property_binding_map)

        self.__disposer:add(function()
            for _, execution in ipairs(self.__property_execution_list) do
                execution.dispose()
            end
        end)

        self.__style:__setup()

        self:__ensure_child_vnode_list()
        local effective_child_vnode_execution_list = {}
        rawset(self, '__effective_child_vnode_list', responsive.reactive.create({}))

        for child_vnode_index, child_vnode in ipairs(self.__child_vnode_list) do
            table.insert(effective_child_vnode_execution_list,
                M.execution.create_value_execution(child_vnode:__get_effective_vnode_list_binding(),
                    function(execution, effective_child_vnode_list)
                        log:trace(string.format(
                            'effective_child_vnode_list changed, vnode: %s, index: %d, #effective_child_vnode_list: %d',
                            self.__id, child_vnode_index, #effective_child_vnode_list))
                        self.__effective_child_vnode_list[child_vnode_index] = effective_child_vnode_list
                    end))
        end
        rawset(self, '__effective_child_vnode_execution_list', effective_child_vnode_execution_list)
        rawset(self, '__effective_child_vnode_execution', M.execution.create_value_execution(responsive.binding.create(
            responsive.computed.create(function()
                log:trace(string.format('effective_child_vnode_list pull, vnode: %s', self.__id))
                local effective_child_vnode_flat_list = {}

                for index = 1, #self.__child_vnode_list do
                    if self.__effective_child_vnode_list[index] then
                        for _, effective_child_vnode in ipairs(self.__effective_child_vnode_list[index]) do
                            table.insert(effective_child_vnode_flat_list, effective_child_vnode)
                        end
                    end
                end

                log:trace(string.format('effective_child_vnode_list pull, vnode: %s, done', self.__id))
                return {
                    data = effective_child_vnode_flat_list
                }
            end), 'data', responsive.binding.MODE.PULL), function(execution, effective_child_vnode_flat_list)
            self:__process_effective_child_vnode_list(effective_child_vnode_flat_list)
        end))
        self.__disposer:add(function()
            self.__effective_child_vnode_list_execution:dispose()
        end)
        if self.type == M.vnode.VNODE_TYPE_VIRTUAL then
            rawset(self, '__stage', M.vnode.STAGE.UPDATE)
        else
            rawset(self, '__stage', M.vnode.STAGE.MOUNT)
        end
    end,
    __mount = function(self, element)
        log:trace(string.format('call mount, vnode: %s, element: %d', self.__id, (element or {
            index = -1
        }).index))
        if self.__stage ~= M.vnode.STAGE.MOUNT then
            error('wrong stage, stage: ' .. self.__stage)
        end
        if not element then
            element = self:__create_element()
        end

        rawset(self, '__element', element)
        M.vnode.__element_key_to_vnode_map[M.vnode.get_element_key(element)] = self
        if not self.__parent_vnode then
            M.vnode.__root_vnode_map[self.__id] = self
        end
        rawset(self, '__stage', M.vnode.STAGE.UPDATE)
    end,
    __update = function(self)
        if self.type == M.vnode.VNODE_TYPE_VIRTUAL then
            error('virtual vnode cannot be updated')
        end
        log:trace(string.format('call update, vnode: %s', self.__id))
        if self.__stage ~= M.vnode.STAGE.UPDATE then
            error('wrong stage, stage: ' .. self.__stage)
        end
        for _, execution in ipairs(self.__property_execution_list) do
            if execution:dirty() then
                execution:process()
            end
        end
        self.__style:__update()

        for _, execution in ipairs(self.__effective_child_vnode_execution_list) do
            if execution:dirty() then
                log:trace(string.format('effective_child_vnode_execution_list dirty, vnode: %s', self.__id))
                execution:process()
            end
        end
        if self.__effective_child_vnode_execution:dirty() then
            self.__effective_child_vnode_execution:process()
        end

        for index = 1, #self.__child_vnode_list do
            if self.__effective_child_vnode_list[index] then
                for _, effective_child_vnode in ipairs(self.__effective_child_vnode_list[index]) do
                    effective_child_vnode:__update()
                end
            end
        end
    end,
    __unmount = function(self)
        log:trace(string.format('call unmount, vnode: %s, element: %d', self.__id, (self.__element or {}).index))
        if self.__stage ~= M.vnode.STAGE.UPDATE then
            error('wrong stage, stage: ' .. self.__stage)
        end

        if self.__element then
            M.vnode.__element_key_to_vnode_map[M.vnode.get_element_key(self.__element)] = nil
            if not self.__parent_vnode then
                M.vnode.__root_vnode_map[self.__id] = nil
            end
        end

        rawset(self, '__element', nil)
        rawset(self, '__stage', M.vnode.STAGE.UPDATE)
    end
    -- #endregion
})

M.vnode.COMPONENT_PROTOTYPE = tools.inherit(M.vnode.PROTOTYPE, {
    __child_template_root_vnode = nil,
    __ensure_child_vnode_list = function(self)
        local component_factory = M.component.get_factory():get_component_factory(self.__template.name)
        local data_descripter = self.__property_descriptor_map:get_descriptor('data')
        local data = {}

        if data_descripter then
            if data_descripter.type == M.__property_descriptor_map.TYPE.DYNAMIC then
                data = responsive.computed.create(load('return ' .. data_descripter.value, nil, 't',
                    responsive.unref(self.__data)))
            elseif data_descripter.type == M.__property_descriptor_map.TYPE.CONST then
                data = data_descripter.value
            end
        end
        rawset(self, '__child_template_root_vnode', component_factory:get({
            parent = self,
            data = data
        }))
    end,
    __get_effective_vnode_list_binding = function(self)
        log:trace(string.format('call get_effective_vnode_list_binding, vnode: %s', self.__id))
        self:__ensure_child_vnode_list()

        return responsive.binding.create({
            data = {self.__child_template_root_vnode}
        }, 'data', responsive.binding.MODE.ONE_TIME)
    end,

    __dispose = function(self)
        self.__disposer:dispose()
        self.__disposed = true
    end,

    __stage = M.vnode.STAGE.SETUP,
    __setup = function(self)
        log:trace(string.format('call setup, vnode: %s', self.__id))
        if self.__stage ~= M.vnode.STAGE.SETUP then
            error('wrong stage, stage: ' .. self.__stage)
        end

        rawset(self, '__stage', M.vnode.STAGE.DONE)
    end,
    __mount = function(self, element)
        error('component cannot mounte to element')
    end,
    __update = function(self)
        error('component cannot update')
    end,
    __unmount = function(self)
        error('component cannot unmount')
    end
})

M.vnode.SLOT_PROTOTYPE = tools.inherit(M.vnode.PROTOTYPE, {
    __child_template_root_vnode = nil,
    __ensure_child_vnode_list = function(self)
        local component_factory = M.component.get_factory():get_component_factory(self.__template.name)
        local data_descripter = self.__property_descriptor_map:get_descriptor('data')
        local data = {}

        if data_descripter then
            if data_descripter.type == M.__property_descriptor_map.TYPE.DYNAMIC then
                data = responsive.computed.create(load('return ' .. data_descripter.value, nil, 't',
                    responsive.unref(self.__data)))
            elseif data_descripter.type == M.__property_descriptor_map.TYPE.CONST then
                data = data_descripter.value
            end
        end
        rawset(self, '__child_template_root_vnode', component_factory:get({
            parent = self,
            data = data
        }))
    end,
    __get_effective_vnode_list_binding = function(self)
        log:trace(string.format('call get_effective_vnode_list_binding, vnode: %s', self.__id))
        self:__ensure_child_vnode_list()

        return responsive.binding.create({
            data = {self.__child_template_root_vnode}
        }, 'data', responsive.binding.MODE.ONE_TIME)
    end,

    __dispose = function(self)
        self.__disposer:dispose()
        self.__disposed = true
    end,

    __stage = M.vnode.STAGE.SETUP,
    __setup = function(self)
        log:trace(string.format('call setup, vnode: %s', self.__id))
        if self.__stage ~= M.vnode.STAGE.SETUP then
            error('wrong stage, stage: ' .. self.__stage)
        end

        rawset(self, '__stage', M.vnode.STAGE.DONE)
    end,
    __mount = function(self, element)
        error('component cannot mounte to element')
    end,
    __update = function(self)
        error('component cannot update')
    end,
    __unmount = function(self)
        error('component cannot unmount')
    end
})

M.vnode.ELEMENT_TYPE_MAP = {
    frame = {
        prototype = M.vnode.ELEMENT_PROTOTYPE,
        vstyle = true
    },
    button = {
        prototype = M.vnode.ELEMENT_PROTOTYPE,
        vstyle = true
    },
    flow = {
        prototype = M.vnode.ELEMENT_PROTOTYPE,
        vstyle = true
    },
    table = {
        prototype = M.vnode.ELEMENT_PROTOTYPE,
        vstyle = true
    },
    textfield = {
        prototype = M.vnode.ELEMENT_PROTOTYPE,
        vstyle = true
    },
    progressbar = {
        prototype = M.vnode.ELEMENT_PROTOTYPE,
        vstyle = true
    },
    checkbox = {
        prototype = M.vnode.ELEMENT_PROTOTYPE,
        vstyle = true
    },
    radiobutton = {
        prototype = M.vnode.ELEMENT_PROTOTYPE,
        vstyle = true
    },
    ['sprite-button'] = {
        prototype = M.vnode.ELEMENT_PROTOTYPE,
        vstyle = true
    },
    sprite = {
        prototype = M.vnode.ELEMENT_PROTOTYPE,
        vstyle = true
    },
    ['scroll-pane'] = {
        prototype = M.vnode.ELEMENT_PROTOTYPE,
        vstyle = true
    },
    ['drop-down'] = {
        prototype = M.vnode.ELEMENT_PROTOTYPE,
        vstyle = true
    },
    line = {
        prototype = M.vnode.ELEMENT_PROTOTYPE,
        vstyle = true
    },
    ['list-box'] = {
        prototype = M.vnode.ELEMENT_PROTOTYPE,
        vstyle = true
    },
    camera = {
        prototype = M.vnode.ELEMENT_PROTOTYPE,
        vstyle = true
    },
    ['choose-elem-button'] = {
        prototype = M.vnode.ELEMENT_PROTOTYPE,
        vstyle = true
    },
    ['text-box'] = {
        prototype = M.vnode.ELEMENT_PROTOTYPE,
        vstyle = true
    },
    slider = {
        prototype = M.vnode.ELEMENT_PROTOTYPE,
        vstyle = true
    },
    minimap = {
        prototype = M.vnode.ELEMENT_PROTOTYPE,
        vstyle = true
    },
    tab = {
        prototype = M.vnode.ELEMENT_PROTOTYPE,
        vstyle = true
    },
    switch = {
        prototype = M.vnode.ELEMENT_PROTOTYPE,
        vstyle = true
    },
    component = {
        prototype = M.vnode.COMPONENT_PROTOTYPE,
        vstyle = false
    },
    slot = {
        prototype = M.vnode.SLOT_PROTOTYPE,
        vstyle = false
    }
}

M.vnode.create = function(definition)
    local template = definition.template

    if not template or not template.type then
        error('incorrect template')
    end

    -- TODO: 支持 slot

    local data = definition.data
    local parent_vnode = definition.parent
    local vnode = tools.inherit_prototype(M.vnode.ELEMENT_TYPE_MAP[template.type].prototype, {
        __property_descriptor_map = M.__property_descriptor_map.create(template),
        __template = template,
        __data = data,
        __parent_vnode = parent_vnode
    })

    if M.vnode.ELEMENT_TYPE_MAP[template.type].vstyle then
        rawset(vnode, '__style', M.vstyle.create(vnode))
    end

    vnode.__disposer:add(function()
        vnode.__style:dispose()
    end)

    return vnode
end
-- #endregion

-- #region component
M.component = {}

M.component.__component_factory_map = {}

M.component.factory = {}

M.component.factory.METATABLE = {
    __type = 'kcomponent_factory'
}

M.component.factory.PROTOTYPE = {
    create = function(self, context)
        return self.__creation_function(context)
    end
}

setmetatable(M.component.factory.PROTOTYPE, M.component.factory.METATABLE)

M.component.get_factory = function()
    return {
        get_component_factory = function(self, name)
            return M.component.__component_factory_map[name]
        end
    }
end

M.component.register_component_factory = function(name, get)
    if M.component.__component_factory_map[name] then
        error('component already exists, name: ' .. name)
    end
    M.component.__component_factory_map[name] = tools.inherit_prototype(M.component.factory.PROTOTYPE, {
        id = unique_id.generate('component'),
        name = name,
        get = get
    })
end
-- #endregion

return M
