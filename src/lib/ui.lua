local log = require("lib.log").get_log('lib.vnode')
local tools = require('lib.tools')
local unique_id = require('lib.unique_id')
local responsive = require('lib.responsive')

local M = {}

M.process_event = function(event)
    local vnode = M.vnode.get_vnode_by_element(event.element)

    if vnode then
        vnode:__process_event(event)
    end
end

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
    __setup = function(self)
        local data = self.__vnode.__data
        local template = self.__vnode.__template
        local property_execution_list = {}

        if not template.style then
            return
        end

        if self.__vnode.type == 'frame' then
            for _, name in ipairs(M.vstyle.STYLE_PROPERTY_NAME_LIST) do
                if template.style[':' .. name] then
                    local binding = responsive.binding.create(data, template.style[':' .. name],
                        responsive.binding.MODE.PULL)
                    local execution = M.execution.create_value_execution(binding, function(execution, value)
                        log:trace('设置 ' .. name .. ': ' .. value)
                        self[name] = value
                    end)

                    table.insert(property_execution_list, execution)
                elseif template.style[name] then
                    local execution = M.execution.create_value_execution(template.style[name],
                        function(execution, value)
                            log:trace('设置 ' .. name .. ': ' .. value)
                            self[name] = value
                        end)

                    table.insert(property_execution_list, execution)
                end
            end
        end

        rawset(self, '__property_execution_list', property_execution_list)
    end,
    __update_ui = function(self)
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
        __id = unique_id.generate('vstyle'),
        __vnode = vnode,
        __property_table = {},
        __property_execution_list = {}
    })
end
-- #endregion

-- #region execution
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
    UPDATE = 'update'
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

M.vnode.ELEMENT_TYPE_MAP = {
    frame = true,
    button = true,
    -- TODO: 应该分成两个分别支持横向和竖向
    flow = true,
    table = true,
    textfield = true,
    progressbar = true,
    checkbox = true,
    radiobutton = true,
    ['sprite-button'] = true,
    sprite = true,
    ['scroll-pane'] = true,
    ['drop-down'] = true,
    line = true,
    ['list-box'] = true,
    camera = true,
    ['choose-elem-button'] = true,
    ['text-box'] = true,
    slider = true,
    minimap = true,
    tab = true,
    switch = true
}

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

M.vnode.element_key_to_vnode_map = {}

M.vnode.get_element_key = function(element)
    return string.format('%d_%d', element.player_index, element.index)

end

M.vnode.get_vnode_by_element = function(element)
    local element_key = M.vnode.get_element_key(element)

    return M.vnode.element_key_to_vnode_map[element_key]
end

M.vnode.PROTOTYPE = {
    __disposed = false,
    -- #region special properties processing
    __get_type = function(self)
        return self.__template.type
    end,
    -- #endregion

    -- #region children processing
    __generate_child_vnode = function(self, child_template, old_vnode_list)
        if old_vnode_list then
            return old_vnode_list
        end

        -- TODO: 需要支持 v-if
        -- TODO: 需要支持 v-for
        -- local func
        -- if child_template[':data'] then
        --     func = load('return ' .. child_template[':data'], nil, 't', responsive.unref(self.__data))
        -- elseif child_template.data then
        --     func = function()
        --         return child_template.data
        --     end
        -- else
        --     func = function()
        --         return {}
        --     end
        -- end
        -- return M.vnode.create({
        --     parent = self,
        --     template = child_template,
        --     data = responsive.computed.create(func)
        -- })

        return M.vnode.create({
            parent = self,
            template = child_template,
            data = self.__data
        })
    end,
    __refresh_child_vnode_list = function(self)
        local child_vnode_list = {}

        if (self.__template.children) then
            for index, child in ipairs(self.__template.children) do
                child_vnode_list[index] = self:__generate_child_vnode(child, self.__child_vnode_list[index])
            end
        end

        self.__child_vnode_list = child_vnode_list
    end,
    __get_effective_child_vnode_list = function(self)
        local effective_vnode_list = {}

        for _, child_vnode in ipairs(self.__child_vnode_list) do
            if child_vnode.type ~= 'virtual' then
                table.insert(effective_vnode_list, child_vnode)
            end
            for _, efffective_child_vnode in ipairs(child_vnode:__get_effective_child_vnode_list()) do
                table.insert(effective_vnode_list, efffective_child_vnode)
            end
        end

        return effective_vnode_list
    end,
    __get_effective_child_vnode_list_binding = function(self)
        -- TODO: 这个binding应该只处理一个子节点，这样可以减少更新的影响
        local computed = responsive.computed.create(function()
            self:__refresh_child_vnode_list()
            return {
                effective_child_vnode_list = self:__get_effective_child_vnode_list()
            }
        end)
        -- TODO: 思考一下这里的脏标志是否还有一定的作用
        return responsive.binding.create(computed, 'effective_child_vnode_list')
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
            if self.__property_binding_map['text'] then
                self.__property_binding_map['text']:set(event.element.text)
            end
            self:__invoke_event_handler('confirmed', event)
        end
    end,

    __invoke_event_handler = function(self, name, event)
        if self.__template['@' .. name] then
            local func = load('return ' .. self.__template['@' .. name], nil, 't', responsive.unref(self.__data))()

            if func then
                func(self, name, event)
            end
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
        local template = self.__template
        local element = self.__element
        local property_execution_list = {}
        local property_binding_map = {}

        for name, _ in pairs(template) do
            if name:sub(1, 1) == ':' or name:sub(1, 1) == '@' or name:sub(1, 1) == '#' then
                name = name:sub(2)
            end
            if not M.vnode.ELEMENT_PROPERTY_DEFINITION[name] and not M.vnode.EVENT_MAP[name] and name ~= 'type' and name ~=
                'style' and name ~= 'children' and name ~= 'data' then
                error('wrong property name in template, name: ' .. name)
            end
        end

        if M.vnode.ELEMENT_TYPE_MAP[self.type] then
            for name, definition in pairs(M.vnode.ELEMENT_PROPERTY_DEFINITION) do
                -- TODO: 增加双向绑定的功能
                -- TODO: 增加双向绑定的测试用例
                if template[':' .. name] then
                    -- TODO: 这里除了把 data 传进去当上下文外，是否还应该有个函数定制上下文
                    local binding = responsive.binding.create(data, template[':' .. name], responsive.binding.MODE.PULL)
                    local execution = M.execution.create_value_execution(binding, function(execution, value)
                        log:trace('设置 ' .. name .. ': ' .. tostring(value))
                        self[name] = value
                    end)

                    table.insert(property_execution_list, execution)
                elseif template['#' .. name] then
                    -- TODO: 这里除了把 data 传进去当上下文外，是否还应该有个函数定制上下文
                    local binding = responsive.binding.create(data, template['#' .. name],
                        responsive.binding.MODE.PULL_AND_PUSH)
                    local execution = M.execution.create_value_execution(binding, function(execution, value)
                        log:trace('设置 ' .. name .. ': ' .. tostring(value))
                        self[name] = value
                    end)

                    table.insert(property_execution_list, execution)
                    property_binding_map[name] = binding
                elseif template[name] then
                    -- TODO: 这里除了把 data 传进去当上下文外，是否还应该有个函数定制上下文
                    local execution = M.execution.create_value_execution(template[name], function(execution, value)
                        log:trace('设置 ' .. name .. ': ' .. tostring(value))
                        self[name] = value
                    end)

                    table.insert(property_execution_list, execution)
                end
            end
        end

        rawset(self, '__property_execution_list', property_execution_list)
        rawset(self, '__property_binding_map', property_binding_map)

        self.__disposer:add(function()
            for _, execution in ipairs(self.__property_execution_list) do
                execution.dispose()
            end
        end)

        self.__style:__setup()
        rawset(self, '__effective_child_vnode_list_execution',
            M.execution
                .create_value_execution(self:__get_effective_child_vnode_list_binding(), function(execution, vnode_list)
                rawset(self, '__effective_child_vnode_list', vnode_list)

                for _, vnode in ipairs(vnode_list) do
                    if vnode.__stage == M.vnode.STAGE.SETUP then
                        vnode:__setup()
                    end
                end
                for _, vnode in ipairs(vnode_list) do
                    if vnode.__stage == M.vnode.STAGE.MOUNT then
                        vnode:__mount(self.__element.add({
                            type = vnode.type,
                            tags = {}
                        }))
                    end
                end

                local vnode_map = {}
                for _, vnode in ipairs(vnode_list) do
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

                -- TODO: 添加测试用例
                for index = 1, #self.__element.children do
                    local element = self.__element.children[index]
                    local vnode = vnode_list[index]

                    if M.vnode.get_vnode_by_element(element) ~= vnode then
                        for index2 = index + 1, #self.__element.children do
                            if self.__element.children[index2] == vnode then
                                self.__element.swap_children(index, index2)
                            end
                        end
                    end
                end
            end))

        self.__disposer:add(function()
            self.__effective_child_vnode_list_execution:dispose()
        end)
        rawset(self, '__stage', M.vnode.STAGE.MOUNT)
    end,
    __mount = function(self, element)
        log:trace(string.format('call mount, vnode: %s, element: %d', self.__id, (element or {}).index))
        if self.__stage ~= M.vnode.STAGE.MOUNT then
            error('wrong stage, stage: ' .. self.__stage)
        end
        if not element then
            error('element cannot be nil')
        end

        rawset(self, '__element', element)
        M.vnode.element_key_to_vnode_map[M.vnode.get_element_key(element)] = self
        rawset(self, '__stage', M.vnode.STAGE.UPDATE)
    end,
    __update_ui = function(self)
        log:trace(string.format('call update_ui, vnode: %s', self.__id))
        if self.__stage ~= M.vnode.STAGE.UPDATE then
            error('wrong stage, stage: ' .. self.__stage)
        end
        if self.__property_execution_list then
            for _, execution in ipairs(self.__property_execution_list) do
                if execution:dirty() then
                    execution:process()
                end
            end
        end
        self.__style:__update_ui()
        if self.__effective_child_vnode_list_execution:dirty() then
            self.__effective_child_vnode_list_execution:process()
        end

        if self.__effective_child_vnode_list then
            for _, vnode in ipairs(self.__effective_child_vnode_list) do
                vnode:__update_ui()
            end
        end
    end,
    __unmount = function(self)
        log:trace(string.format('call unmount, vnode: %s, element: %d', self.__id, (self.__element or {}).index))
        if self.__stage ~= M.vnode.STAGE.UPDATE then
            error('wrong stage, stage: ' .. self.__stage)
        end

        if self.__element then
            M.vnode.element_key_to_vnode_map[M.vnode.get_element_key(self.__element)] = nil
        end

        rawset(self, '__element', nil)
        rawset(self, '__stage', M.vnode.STAGE.UPDATE)
    end
    -- #endregion
}
setmetatable(M.vnode.PROTOTYPE, M.vnode.METATABLE)

M.vnode.create = function(definition)
    local template = definition.template

    if not template or not template.type then
        error('incorrect template')
    end

    local data = definition.data
    local parent_vnode = definition.parent
    local vnode = tools.inherit_prototype(M.vnode.PROTOTYPE, {
        __id = unique_id.generate('vnode'),
        __definition = definition,
        __template = template,
        __data = data,
        __parent_vnode = parent_vnode,
        __element = nil,
        __property_table = {},
        __binding_set_map = {},
        __property_execution_list = nil,
        __child_vnode_list = {},
        __disposer = tools.disposer.create()
    })

    rawset(vnode, '__style', M.vstyle.create(vnode))

    vnode.__disposer:add(function()
        vnode.__style:dispose()
    end)

    return vnode
end
-- #endregion

return M
