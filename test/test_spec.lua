local current_file_path = debug.getinfo(1).source:sub(2) -- 去掉路径前面的 '@'
print(current_file_path)
local path_separator = package.config:sub(1, 1) -- 获取路径分隔符，Windows 是 '\'，Unix 是 '/'
local parent_dir = current_file_path:match('(.*' .. path_separator .. ').*' .. path_separator)

package.path = package.path .. ';' .. parent_dir .. 'src/?.lua' .. ';' .. parent_dir .. 'test/?.lua'

local cjson = require('cjson')
local log = require('lib.log')
log.in_game = false
log.global_min_level = log.level.debug

local function remove_function(t)
    local result = {}
    for k, v in pairs(t) do
        if type(v) ~= 'function' then
            if type(v) == 'table' then
                result[k] = remove_function(v)
            else
                result[k] = v
            end
        end
    end
    return result
end

local function table_to_json(t)
    return cjson.encode(remove_function(t))
end

describe('unique_id', function()
    it('call generate', function()
        local helper = require('helper')
        local unique_id = require('lib.unique_id')

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
        local helper = require('helper')
        local log = require('lib.log')

        log.in_game = false
        log.warn('test')
    end)
end)

describe('responsive', function()
    describe('notifier', function()
        it('check type', function()
            local helper = require('helper')
            local responsive = require('lib.responsive')

            local notifier = responsive.notifier.create()

            assert(getmetatable(notifier) == responsive.notifier.METATABLE)
        end)

        it('add listener', function()
            local helper = require('helper')
            local responsive = require('lib.responsive')

            local notifier = responsive.notifier.create()
            local log_list = {}

            notifier:add_listener('read', function(sender, event, message)
                table.insert(log_list, 'read' .. sender .. event .. message)
            end)
            notifier:add_listener('write', function(sender, event, message)
                table.insert(log_list, 'write' .. sender .. event .. message)
            end)

            notifier:emit('sender', 'read', 'message')
            notifier:emit('sender', 'write', 'message')

            assert(#log_list == 2)
            assert(log_list[1] == "readsenderreadmessage")
            assert(log_list[2] == "writesenderwritemessage")
        end)

        it('dispose', function()
            local helper = require('helper')
            local responsive = require('lib.responsive')

            local notifier = responsive.notifier.create()
            local log_list = {}

            local dispose = notifier:add_listener('read', function(sender, event, message)
                table.insert(log_list, 'read' .. sender .. event .. message)
            end)
            notifier:add_listener('write', function(sender, event, message)
                table.insert(log_list, 'write' .. sender .. event .. message)
            end)

            notifier:emit('sender', 'read', 'message')
            notifier:emit('sender', 'write', 'message')
            dispose()
            notifier:emit('sender', 'read', 'message')

            assert(#log_list == 2)
            assert(log_list[1] == "readsenderreadmessage")
            assert(log_list[2] == "writesenderwritemessage")
        end)

        it('parent', function()
            local helper = require('helper')
            local responsive = require('lib.responsive')

            local parent_notifier = responsive.notifier.create()
            local notifier = responsive.notifier.create(parent_notifier)
            local log_list = {}

            parent_notifier:add_listener('read', function(sender, event, message)
                table.insert(log_list, 'read' .. ' ' .. sender .. ' ' .. event .. ' ' .. message)
            end)
            parent_notifier:add_listener('write', function(sender, event, message)
                table.insert(log_list, 'write' .. ' ' .. sender .. ' ' .. event .. ' ' .. message)
            end)

            notifier:emit('sender', 'read', 'message')
            notifier:emit('sender', 'write', 'message')

            assert(#log_list == 2)
            assert(log_list[1] == "read sender read message")
            assert(log_list[2] == "write sender write message")
        end)
    end)

    describe('reactive', function()
        it('check type', function()
            local helper = require('helper')
            local responsive = require('lib.responsive')

            local reactive = responsive.reactive.create({
                property1 = 'test1'
            })

            assert(getmetatable(reactive) == responsive.reactive.METATABLE)
        end)
        it('get and set', function()
            local helper = require('helper')
            local responsive = require('lib.responsive')

            local reactive1 = responsive.reactive.create({
                property1 = 'test1'
            })
            local reactive2 = responsive.reactive.create()

            reactive2.property1 = 'test2'

            assert(reactive1.property1 == 'test1')
            assert(reactive2.property1 == 'test2')
        end)

        it('add listener', function()
            local helper = require('helper')
            local responsive = require('lib.responsive')

            local reactive = responsive.reactive.create()
            local log_list = {}

            reactive:__add_listener(responsive.EVENT.PROPERTY_READ,
                function(reactive, event, name, old_value, new_value)
                    table.insert(log_list, event .. ' ' .. name)
                end)

            reactive:__add_listener(responsive.EVENT.PROPERTY_CHANGED,
                function(reactive, event, name, old_value, new_value)
                    table.insert(log_list, event .. ' ' .. name)
                end)

            reactive.property1 = 'test1'
            local property1 = reactive.property1

            log.debug(table_to_json(log_list))

            assert(log_list[1] == 'property_changed property1')
            assert(log_list[2] == 'property_read property1')
        end)

        it('remove listener', function()
            local helper = require('helper')
            local responsive = require('lib.responsive')

            local reactive1 = responsive.reactive.create()
            local log_list = {}

            local remove_listener = reactive1:__add_listener(responsive.EVENT.PROPERTY_CHANGED,
                function(responsive, event, name, old_value, new_value)
                    table.insert(log_list, event .. ' ' .. name)
                end)

            remove_listener()

            reactive1.property1 = 'test1'

            reactive1:__add_listener(responsive.EVENT.PROPERTY_CHANGED,
                function(responsive, event, name, old_value, new_value)
                    table.insert(log_list, event .. ' ' .. name)
                end)

            reactive1.property1 = 'test2'

            log.debug(table_to_json(log_list))
            assert(#log_list == 1)
            assert(log_list[1] == 'property_changed property1')
        end)
    end)

    describe('watch', function()
        it('check type', function()
            local helper = require('helper')
            local responsive = require('lib.responsive')

            local watch = responsive.watch.create()

            assert(getmetatable(watch) == responsive.watch.METATABLE)
        end)

        it('record', function()
            local helper = require('helper')
            local responsive = require('lib.responsive')

            local watch = responsive.watch.create()
            local reactive = responsive.reactive.create({
                property1 = 'test1'
            })
            local log_list = {}

            watch:add_listener(responsive.EVENT.PROPERTY_CHANGED, function(sender, event, name, old_value, new_value)
                table.insert(log_list,
                    sender.__id .. ' ' .. event .. ' ' .. name .. ' ' .. old_value .. ' ' .. new_value)
            end)
            watch:record()
            local property1 = reactive.property1
            watch:stop()

            table.insert(log_list, 'begin')
            reactive.property1 = 'test1_changed'

            log.debug(table_to_json(log_list))
            assert(#log_list == 2)
            assert(log_list[1] == 'begin')
            assert(log_list[2] == reactive.__id .. ' property_changed property1 test1 test1_changed')
        end)
    end)

    describe('binding', function()
        it('check type', function()
            local helper = require('helper')
            local responsive = require('lib.responsive')

            local raw_table = {
                property1 = 'test1'
            }
            local binding = responsive.binding.create(raw_table, 'property1', responsive.binding.MODE.PULL)

            assert(getmetatable(binding) == responsive.binding.METATABLE)
        end)

        it('pull', function()
            local helper = require('helper')
            local responsive = require('lib.responsive')

            local raw_table = {
                property1 = 'test1'
            }
            local binding1 = responsive.binding.create(raw_table, 'property1', responsive.binding.MODE.PULL)

            assert(binding1:get() == 'test1')
        end)

        it('pull with error', function()
            local helper = require('helper')
            local responsive = require('lib.responsive')

            local raw_table = {
                property1 = 'test1'
            }
            local binding = responsive.binding.create(raw_table, 'property1/0', responsive.binding.MODE.PULL)
            local status, result = pcall(binding.get, binding)

            assert(not status)
            assert(type(result) == 'string')
        end)

        it('push', function()
            local helper = require('helper')
            local responsive = require('lib.responsive')

            local raw_table = {
                property1 = 'test1'
            }
            local binding1 = responsive.binding.create(raw_table, 'property1', responsive.binding.MODE.PULL_AND_PUSH)

            binding1:set('test2')
            assert(raw_table.property1 == 'test2')
        end)

        it('dirty', function()
            local helper = require('helper')
            local responsive = require('lib.responsive')

            local reactive = responsive.reactive.create({
                property1 = 'test1'
            })
            local binding = responsive.binding.create(reactive, 'property1', responsive.binding.MODE.PULL_AND_PUSH)

            assert(binding:dirty())
            assert(binding:get() == 'test1')

            binding:set('test2')

            assert(not binding:dirty())
            assert(binding:get() == 'test2')
        end)
    end)

    describe('execution', function()
        it('one binding', function()
            local helper = require('helper')
            local responsive = require('lib.responsive')

            local execution_list = {}
            local data = responsive.reactive.create({
                property1 = 'test1',
                property2 = 'test2'
            })
            local log_list = {}

            local binding = responsive.binding.create(data, 'property1', responsive.binding.MODE.PULL)
            table.insert(execution_list, responsive.execution.create_execution_for_binding(binding, function(value)
                table.insert(log_list, 'process property1 ' .. value)
            end))
            local execution = responsive.execution.create_sequence_execution(execution_list)

            execution:process()
            execution:process()
            data.property1 = 'test1_changed'
            execution:process()
            execution:process()
            log.debug(table_to_json(log_list))
            assert(#log_list == 2)
            assert(log_list[1] == 'process property1 test1')
            assert(log_list[2] == 'process property1 test1_changed')
        end)

        it('multiple binding', function()
            local helper = require('helper')
            local responsive = require('lib.responsive')

            local data = responsive.reactive.create({
                property1 = 'test1',
                property2 = {
                    property3 = 'test3'
                }
            })
            local log_list = {}
            local execution_list = {}

            local binding1 = responsive.binding.create(data, 'property1', responsive.binding.MODE.PULL)
            table.insert(execution_list, responsive.execution.create_execution_for_binding(binding1, function(value)
                table.insert(log_list, 'process property1 ' .. value)
            end))

            local binding2 = responsive.binding.create(data, 'property2.property3', responsive.binding.MODE.PULL)
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

        it('bidirection binding', function()
            local helper = require('helper')
            local responsive = require('lib.responsive')

            local data = responsive.reactive.create({
                property1 = 'test1',
                property2 = {
                    property3 = 'test3'
                }
            })
            local log_list = {}
            local execution_list = {}
            local binding = responsive.binding
                                .create(data, 'property2.property3', responsive.binding.MODE.PULL_AND_PUSH)
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
end)
