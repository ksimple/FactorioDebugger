local log = require("lib.log").get_log('lib.vnode')
local tools = require('lib.tools')
local unique_id = require('lib.unique_id')
local responsive = require('lib.responsive')

local M = {}

-- #region vstyle
M.vstyle = {}
M.vstyle.METATABLE = {
    __type = 'kvstyle',
    __index = function(self, name)
        if string.sub(name, 1, 2) == '__' then
            return rawget(self, name)
        else
            -- TODO: 这里是不是应该直接从 element 上读取？
            return rawget(self, '__property_table')[name]
        end
    end,
    __newindex = function(self, name, value)
        if string.sub(name, 1, 2) == '__' then
            error('not supported, name: ' .. name)
        else
            self.__vnode.__element.style[name] = value
            self.__property_table[name] = value
        end
    end
}
M.vstyle.PROTOTYPE = {
    __setup = function(self)
        local data = self.__vnode.__data
        local template = self.__vnode.__template
        local property_execution_list = {}

        if not template.style then
            return
        end

        if self.__vnode.type == 'frame' then
            for _, name in ipairs({'width', 'height'}) do
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
    UPDATE = 'update'
}

M.vnode.ELEMENT_KEY = '__k_vnode'

M.vnode.METATABLE = {
    __type = 'kvnode',
    __index = function(vnode, name)
        if string.sub(name, 1, 2) == '__' then
            return rawget(vnode, name)
        else
            return rawget(vnode, '__get_' .. name)(vnode)
        end
    end,
    __newindex = function(vnode, name, value)
        if string.sub(name, 1, 2) == '__' then
            error('not supported, name: ' .. name)
        else
            vnode['__set_' .. name](vnode, value)
        end
    end
}

M.vnode.PROTOTYPE = {
    __stage = M.vnode.STAGE.SETUP,
    __get_type = function(self)
        return self.__template.type
    end,
    __get_caption = function(self)
        local name = 'caption'
        return self.__property_table[name]
    end,
    __set_caption = function(self, value)
        local name = 'caption'
        self.__element[name] = value
        self.__property_table[name] = value
    end,
    __update_ui = function(self)
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
    end,
    __dispose = function(self)
        for _, binding in pairs(self.__binding_list) do
            binding:dispose()
        end
        for _, dispose in pairs(self.__dispose_list) do
            dispose()
        end
        if self.__execution then
            self.__execution:dispose()
        end
    end,
    __setup = function(self)
        if self.__stage ~= M.vnode.STAGE.SETUP then
            error('wrong stage, stage: ' .. self.__stage)
        end
        local data = self.__data
        local template = self.__template
        local element = self.__element
        local property_execution_list = {}

        element[M.vnode.ELEMENT_KEY] = self
        if self.type == 'frame' then
            for _, name in ipairs({'caption'}) do
                if template[':' .. name] then
                    local binding = responsive.binding.create(data, template[':' .. name], responsive.binding.MODE.PULL)
                    local execution = M.execution.create_value_execution(binding, function(execution, value)
                        log:trace('设置 ' .. name .. ': ' .. value)
                        self[name] = value
                    end)

                    table.insert(property_execution_list, execution)
                elseif template[name] then
                    local execution = M.execution.create_value_execution(template[name], function(execution, value)
                        log:trace('设置 ' .. name .. ': ' .. value)
                        self[name] = value
                    end)

                    table.insert(property_execution_list, execution)
                end
            end
        end

        rawset(self, '__property_execution_list', property_execution_list)
        self.__style:__setup()
        -- TODO: 需要处理一下子元素

        rawset(self, '__stage', M.vnode.STAGE.UPDATE)
    end
}
setmetatable(M.vnode.PROTOTYPE, M.vnode.METATABLE)

M.vnode.create = function(element, parent_vnode, definition)
    if not element then
        error('no element specified')
    end

    local template = definition.template
    local data = definition.data

    if not template or not template.type or element.type ~= template.type then
        error('incorrect template')
    end

    local vnode = tools.inherit_prototype(M.vnode.PROTOTYPE, {
        __id = unique_id.generate('vnode'),
        __definition = definition,
        __template = template,
        __data = data,
        __parent_vnode = parent_vnode,
        __element = element,
        __property_table = {},
        __binding_list = {},
        __binding_set_map = {},
        __dispose_list = {},
        __property_execution_list = nil
    })

    rawset(vnode, '__style', M.vstyle.create(vnode))

    return vnode
end
-- #endregion

return M
