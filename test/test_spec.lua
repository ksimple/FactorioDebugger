local current_file_path = debug.getinfo(1).source:sub(2) -- 去掉路径前面的 "@"
local path_separator = package.config:sub(1, 1) -- 获取路径分隔符，Windows 是 "\"，Unix 是 "/"
local parent_dir = current_file_path:match("(.*" .. path_separator .. ").*" .. path_separator)

package.path = package.path .. ';' .. parent_dir .. 'src/?.lua' .. ';' .. parent_dir .. 'test/?.lua'

describe('unique_id', function()
    it("call generate", function()
        local helper = require("helper")
        local unique_id = require('lib.unique_id')

        helper.set_global({})

        assert(unique_id.generate(12345678) == 'none_12345678_100000000')
        assert(unique_id.generate(12345678, 'test') == 'test_12345678_100000001')

        helper.set_global({
            unique_id = 200000000
        })

        assert(unique_id.generate(12345678) == 'none_12345678_200000000')
        assert(unique_id.generate(12345678, 'test') == 'test_12345678_200000001')
    end)
end)

describe('responsive', function()
    it('get and set', function()
        local helper = require("helper")
        local responsive = require('lib.responsive')

        helper.set_global({})

        local reactive_table1 = responsive.create_reactive_table(100000000)
        local reactive_table2 = responsive.create_reactive_table(100000000)

        reactive_table1.property1 = 'test1'
        reactive_table2.property1 = 'test2'

        assert(reactive_table1.property1 == 'test1')
        assert(reactive_table1.__id == 'rt_100000000_100000000')
        assert(reactive_table2.property1 == 'test2')
        assert(reactive_table2.__id == 'rt_100000000_100000001')
    end)

    it('add listener', function()
        local helper = require("helper")
        local responsive = require('lib.responsive')

        helper.set_global({})

        local reactive_table1 = responsive.create_reactive_table(100000000)
        local change_log_list = {}

        reactive_table1.__add_listener(responsive.EVENT.PROPERTY_READ, function(responsive, name, old_value, new_value)
            table.insert(change_log_list, 'read_' .. responsive.__id .. '_' .. name)
        end)

        reactive_table1.__add_listener(responsive.EVENT.PROPERTY_CHANGED,
            function(responsive, name, old_value, new_value)
                table.insert(change_log_list, 'write_' .. responsive.__id .. '_' .. name)
            end)

        reactive_table1.property1 = 'test1'
        assert(change_log_list[1] == 'write_rt_100000000_100000000_property1')
        local propert1 = reactive_table1.property1
        assert(change_log_list[2] == 'read_rt_100000000_100000000_property1')
    end)

    it('remove listener', function()
        local helper = require("helper")
        local responsive = require('lib.responsive')

        helper.set_global({})

        local reactive_table1 = responsive.create_reactive_table(100000000)
        local change_log_list = {}

        local remove_listener = reactive_table1.__add_listener(responsive.EVENT.PROPERTY_CHANGED,
            function(responsive, name, old_value, new_value)
                table.insert(change_log_list, responsive.__id .. '_' .. name)
            end)

        remove_listener()

        reactive_table1.property1 = 'test1'
        assert(#change_log_list == 0)

        reactive_table1.__add_listener(responsive.EVENT.PROPERTY_CHANGED,
            function(responsive, name, old_value, new_value)
                table.insert(change_log_list, responsive.__id .. '_' .. name)
            end)

        reactive_table1.property1 = 'test2'
        assert(change_log_list[1] == 'rt_100000000_100000000_property1')
    end)

    it('bind pull', function()
        local helper = require("helper")
        local responsive = require('lib.responsive')

        helper.set_global({})

        local raw_table = {
            property1 = 'test1'
        }
        local bind1 = responsive.create_bind(100000000, raw_table, 'property1', responsive.BIND_DIRECTION.PULL)

        assert(bind1.get() == 'test1')
    end)

    it('bind pull with error', function()
        local helper = require("helper")
        local responsive = require('lib.responsive')

        helper.set_global({})

        local raw_table = {
            property1 = 'test1'
        }
        local bind1 = responsive.create_bind(100000000, raw_table, 'property1/0', responsive.BIND_DIRECTION.PULL)
        local status, result = pcall(bind1.get)

        assert(not status)
        assert(type(result) == 'string')
    end)

    it('bind push', function()
        local helper = require("helper")
        local responsive = require('lib.responsive')

        helper.set_global({})

        local raw_table = {
            property1 = 'test1'
        }
        local bind1 = responsive.create_bind(100000000, raw_table, 'property1', responsive.BIND_DIRECTION.PULL_AND_PUSH)

        bind1.set('test2')
        assert(raw_table.property1 == 'test2')
    end)

    it('bind dirty', function()
        local helper = require("helper")
        local responsive = require('lib.responsive')

        helper.set_global({})

        local reactive_table = responsive.create_reactive_table(100000000)
        local bind1 = responsive.create_bind(100000000, reactive_table, 'property1',
            responsive.BIND_DIRECTION.PULL_AND_PUSH)

        reactive_table.property1 = 'test1'
        bind1.get()
        assert(not bind1.dirty())
        assert(bind1.get() == 'test1')
        bind1.set('test2')
        assert(bind1.dirty())
        assert(bind1.get() == 'test2')
    end)
end)
