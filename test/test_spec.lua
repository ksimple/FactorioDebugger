local current_file_path = debug.getinfo(1).source:sub(2) -- 去掉路径前面的 "@"
local path_separator = package.config:sub(1, 1) -- 获取路径分隔符，Windows 是 "\"，Unix 是 "/"
local parent_dir = current_file_path:match("(.*" .. path_separator .. ").*" .. path_separator)

package.path = package.path .. ';' .. parent_dir .. 'src/?.lua' .. ';' .. parent_dir .. 'test/?.lua'

describe('unique_id', function()
    it("call generate", function()
        local helper = require("helper")
        local unique_id = require('lib.unique_id')

        helper.set_global({})

        assert(unique_id.generate() == 'none_100000000_100000000')
        assert(unique_id.generate('test') == 'test_100000000_100000001')

        helper.set_global({
            unique_id = 200000000
        })

        assert(unique_id.generate() == 'none_100000000_200000000')
        assert(unique_id.generate('test') == 'test_100000000_200000001')
    end)
end)

describe('log', function()
    it('test warn output', function()
        local helper = require("helper")
        local log = require('lib.log')

        helper.set_global({})
        log.in_game = false
        log.warn('test')
    end)
end)

describe('responsive', function()
    it('reactive_table get and set', function()
        local helper = require("helper")
        local responsive = require('lib.responsive')

        helper.set_global({})

        local reactive_table1 = responsive.create_reactive_table({
            property1 = 'test1'
        })
        local reactive_table2 = responsive.create_reactive_table()

        reactive_table2.property1 = 'test2'

        assert(reactive_table1.property1 == 'test1')
        assert(reactive_table1.__id == 'rt_100000000_100000000')
        assert(reactive_table2.property1 == 'test2')
        assert(reactive_table2.__id == 'rt_100000000_100000001')
    end)

    it('reactive_table add listener', function()
        local helper = require("helper")
        local responsive = require('lib.responsive')

        helper.set_global({})

        local reactive_table1 = responsive.create_reactive_table()
        local log_list = {}

        reactive_table1:__add_listener(responsive.EVENT.PROPERTY_READ, function(responsive, name, old_value, new_value)
            table.insert(log_list, 'read_' .. responsive.__id .. '_' .. name)
        end)

        reactive_table1:__add_listener(responsive.EVENT.PROPERTY_CHANGED,
            function(responsive, name, old_value, new_value)
                table.insert(log_list, 'write_' .. responsive.__id .. '_' .. name)
            end)

        reactive_table1.property1 = 'test1'
        assert(log_list[1] == 'write_rt_100000000_100000000_property1')
        local property1 = reactive_table1.property1
        assert(log_list[2] == 'read_rt_100000000_100000000_property1')
    end)

    it('reactive_table remove listener', function()
        local helper = require("helper")
        local responsive = require('lib.responsive')

        helper.set_global({})

        local reactive_table1 = responsive.create_reactive_table()
        local log_list = {}

        local remove_listener = reactive_table1:__add_listener(responsive.EVENT.PROPERTY_CHANGED,
            function(responsive, name, old_value, new_value)
                table.insert(log_list, responsive.__id .. '_' .. name)
            end)

        remove_listener()

        reactive_table1.property1 = 'test1'
        assert(#log_list == 0)

        reactive_table1:__add_listener(responsive.EVENT.PROPERTY_CHANGED,
            function(responsive, name, old_value, new_value)
                table.insert(log_list, responsive.__id .. '_' .. name)
            end)

        reactive_table1.property1 = 'test2'
        assert(log_list[1] == 'rt_100000000_100000000_property1')
    end)

    it('binding check type', function()
        local helper = require("helper")
        local responsive = require('lib.responsive')

        helper.set_global({})

        local raw_table = {
            property1 = 'test1'
        }
        local binding1 = responsive.create_binding(raw_table, 'property1', responsive.BINDING_MODE.PULL)

        assert(getmetatable(binding1) == responsive.BINDING_METATABLE)
    end)

    it('binding pull', function()
        local helper = require("helper")
        local responsive = require('lib.responsive')

        helper.set_global({})

        local raw_table = {
            property1 = 'test1'
        }
        local binding1 = responsive.create_binding(raw_table, 'property1', responsive.BINDING_MODE.PULL)

        assert(binding1:get() == 'test1')
    end)

    it('binding pull with error', function()
        local helper = require("helper")
        local responsive = require('lib.responsive')

        helper.set_global({})

        local raw_table = {
            property1 = 'test1'
        }
        local binding1 = responsive.create_binding(raw_table, 'property1/0', responsive.BINDING_MODE.PULL)
        local status, result = pcall(binding1.get, binding1)

        assert(not status)
        assert(type(result) == 'string')
    end)

    it('binding push', function()
        local helper = require("helper")
        local responsive = require('lib.responsive')

        helper.set_global({})

        local raw_table = {
            property1 = 'test1'
        }
        local binding1 = responsive.create_binding(raw_table, 'property1', responsive.BINDING_MODE.PULL_AND_PUSH)

        binding1:set('test2')
        assert(raw_table.property1 == 'test2')
    end)

    it('binding dirty', function()
        local helper = require("helper")
        local responsive = require('lib.responsive')

        helper.set_global({})

        local reactive_table = responsive.create_reactive_table()
        local binding1 = responsive.create_binding(reactive_table, 'property1', responsive.BINDING_MODE.PULL_AND_PUSH)

        reactive_table.property1 = 'test1'
        binding1:get()
        assert(binding1:dirty())
        assert(binding1:get() == 'test1')
        binding1:set('test2')
        assert(not binding1:dirty())
        assert(binding1:get() == 'test2')
    end)

    it('execution_plan one binding', function()
        local helper = require("helper")
        local responsive = require('lib.responsive')

        helper.set_global({})
        local execution_list = {}
        local data = responsive.create_reactive_table({
            property1 = 'test1',
            property2 = 'test2'
        })
        local log_list = {}

        local binding = responsive.create_binding(data, "property1", responsive.BINDING_MODE.PULL)
        table.insert(execution_list, responsive.execution.create_execution_for_binding(binding, function(value)
            table.insert(log_list, 'process property1 ' .. value)
        end))
        local execution = responsive.execution.create_sequence_execution(execution_list)

        execution:process()
        assert(#log_list == 1)
        execution:process()
        assert(#log_list == 1)
        data.property1 = 'test1_changed'
        execution:process()
        assert(#log_list == 2)
        execution:process()
        assert(#log_list == 2)
        assert(log_list[1] == 'process property1 test1')
        assert(log_list[2] == 'process property1 test1_changed')
    end)

    it('execution_plan multiple binding', function()
        local helper = require("helper")
        local responsive = require('lib.responsive')

        helper.set_global({})
        local data = responsive.create_reactive_table({
            property1 = 'test1',
            property2 = {
                property3 = 'test3'
            }
        })
        local log_list = {}
        local execution_list = {}

        local binding1 = responsive.create_binding(data, 'property1', responsive.BINDING_MODE.PULL)
        table.insert(execution_list, responsive.execution.create_execution_for_binding(binding1, function(value)
            table.insert(log_list, 'process property1 ' .. value)
        end))

        local binding2 = responsive.create_binding(data, 'property2.property3', responsive.BINDING_MODE.PULL)
        table.insert(execution_list, responsive.execution.create_execution_for_binding(binding2, function(value)
            table.insert(log_list, 'process property2.property3 ' .. value)
        end))

        local execution = responsive.execution.create_sequence_execution(execution_list)

        execution:process()
        assert(#log_list == 2)
        execution:process()
        assert(#log_list == 2)
        data.property1 = 'test1_changed'
        data.property2.property3 = 'test3_changed'
        execution:process()
        assert(#log_list == 4)
        execution:process()
        assert(#log_list == 4)
        assert(log_list[1] == 'process property1 test1')
        assert(log_list[2] == 'process property2.property3 test3')
        assert(log_list[3] == 'process property1 test1_changed')
        assert(log_list[4] == 'process property2.property3 test3_changed')
    end)

    it('execution_plan bidirection binding', function()
        local helper = require("helper")
        local responsive = require('lib.responsive')

        helper.set_global({})
        local data = responsive.create_reactive_table({
            property1 = 'test1',
            property2 = {
                property3 = 'test3'
            }
        })
        local log_list = {}
        local execution_list = {}
        local binding = responsive.create_binding(data, "property2.property3", responsive.BINDING_MODE.PULL_AND_PUSH)
        table.insert(execution_list, responsive.execution.create_execution_for_binding(binding, function(value)
            table.insert(log_list, 'process property2.property3 ' .. value)
        end))

        local execution = responsive.execution.create_sequence_execution(execution_list)

        execution:process()
        assert(#log_list == 1)
        ---@diagnostic disable-next-line: need-check-nil
        binding:set('test3_changed')
        execution:process()
        assert(#log_list == 1)
        assert(data.property2.property3 == 'test3_changed')
    end)
end)
