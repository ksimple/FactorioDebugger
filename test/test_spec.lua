local current_file_path = debug.getinfo(1).source:sub(2) -- 去掉路径前面的 '@'
print(current_file_path)
local path_separator = package.config:sub(1, 1) -- 获取路径分隔符，Windows 是 '\'，Unix 是 '/'
local parent_dir = current_file_path:match('(.*' .. path_separator .. ').*' .. path_separator)

package.path = package.path .. ';' .. parent_dir .. 'src/?.lua' .. ';' .. parent_dir .. 'test/?.lua'

local log = require('lib.log')
local tools = require('lib.tools')

log.in_game = false
log.global_min_level = log.LEVEL.TRACE
log = log.get_log('test')

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
        local log = require('lib.log').get_log('testmodule')

        log:warn('test')

        log = require('lib.log').get_log('01234567890123456789.testmodule')
        log:error('test long module')
    end)
end)

describe('tools', function()
    it('inherit_prototype', function()
        local helper = require('helper')
        local tools = require('lib.tools')

        local prototype = {
            const_boolean = false,
            const_integer = 1,
            const_object = {},
            const_volatile = tools.volatile.create(function()
                return {
                    property = 'test'
                }
            end),
            const_function = function()

            end,
            override_integer = 0
        }
        local object1 = tools.inherit_prototype(prototype, {
            dynamic_integer = 1,
            override_integer = 1
        })
        local object2 = tools.inherit_prototype(prototype, {
            dynamic_integer = 2,
            override_integer = 2
        })

        log:debug(object1)
        assert(object1.const_boolean == false)
        assert(object1.const_integer == 1)
        assert(object1.const_object == prototype.const_object)
        assert(object1.const_function == prototype.const_function)
        assert(object1.dynamic_integer == 1)
        assert(object1.override_integer == 1)
        assert(type(object1.const_volatile) == 'table')
        assert(object1.const_volatile.property == 'test')

        log:debug(object2)
        assert(object2.const_boolean == false)
        assert(object2.const_integer == 1)
        assert(object2.const_object == prototype.const_object)
        assert(object2.const_function == prototype.const_function)
        assert(object2.dynamic_integer == 2)
        assert(object2.override_integer == 2)
        assert(type(object2.const_volatile) == 'table')
        assert(object2.const_volatile.property == 'test')

        assert(object1.const_volatile ~= object2.const_volatile)
    end)
    describe('disposer', function()
        it('check type', function()
            local helper = require('helper')
            local tools = require('lib.tools')

            local disposer = tools.disposer.create()

            assert(getmetatable(disposer) == tools.disposer.METATABLE)
        end)
        it('dispose', function()
            local helper = require('helper')
            local tools = require('lib.tools')

            local disposer = tools.disposer.create()
            local log_list = {}

            disposer:add(function()
                table.insert(log_list, 'dispose 1 called')
            end)

            disposer:add(function()
                table.insert(log_list, 'dispose 2 called')
            end)

            assert(#log_list == 0)

            disposer:dispose()
            assert(#log_list == 2)

            local remove_handler = disposer:add(function()
                table.insert(log_list, 'dispose 3 called')
            end)
            disposer:add(function()
                table.insert(log_list, 'dispose 4 called')
            end)

            remove_handler()

            disposer:dispose()
            assert(#log_list == 3)
            assert(log_list[1] == 'dispose 1 called')
            assert(log_list[2] == 'dispose 2 called')
            assert(log_list[3] == 'dispose 4 called')
        end)
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
        it('add and remove listener 1', function()
            local helper = require('helper')
            local responsive = require('lib.responsive')

            local notifier = responsive.notifier.create()
            local log_list = {}

            notifier:add_listener('read', function(sender, event, message)
                table.insert(log_list, 'read' .. ' ' .. sender .. ' ' .. event .. ' ' .. message)
            end)
            notifier:add_listener('write', function(sender, event, message)
                table.insert(log_list, '1 write' .. ' ' .. sender .. ' ' .. event .. ' ' .. message)
            end)
            local dispose2 = notifier:add_listener('write', function(sender, event, message)
                table.insert(log_list, '2 write' .. ' ' .. sender .. ' ' .. event .. ' ' .. message)
            end)
            local dispose3 = notifier:add_listener('write', function(sender, event, message)
                table.insert(log_list, '3 write' .. ' ' .. sender .. ' ' .. event .. ' ' .. message)
            end)
            notifier:add_listener('write', function(sender, event, message)
                table.insert(log_list, '4 write' .. ' ' .. sender .. ' ' .. event .. ' ' .. message)
            end)
            dispose2()
            dispose3()
            notifier:add_listener('write', function(sender, event, message)
                table.insert(log_list, '5 write' .. ' ' .. sender .. ' ' .. event .. ' ' .. message)
            end)

            notifier:emit('sender', 'read', 'message')
            notifier:emit('sender', 'write', 'message')

            log:debug(log_list)
            assert(notifier:get_listener_count('read') == 1)
            assert(notifier:get_listener_count('write') == 3)
            assert(#log_list == 4)
            assert(log_list[1] == "read sender read message")
            assert(log_list[2] == "1 write sender write message")
            assert(log_list[3] == "4 write sender write message")
            assert(log_list[4] == "5 write sender write message")
        end)
        it('add and remove listener 2', function()
            local helper = require('helper')
            local responsive = require('lib.responsive')

            local notifier = responsive.notifier.create()
            local log_list = {}

            local dispose = notifier:add_listener('read', function(sender, event, message)
                table.insert(log_list, 'read' .. ' ' .. sender .. ' ' .. event .. ' ' .. message)
            end)
            notifier:add_listener('read', function(sender, event, message)
                table.insert(log_list, 'read' .. ' ' .. sender .. ' ' .. event .. ' ' .. message)
            end)
            notifier:add_listener('write', function(sender, event, message)
                table.insert(log_list, 'write' .. ' ' .. sender .. ' ' .. event .. ' ' .. message)
            end)

            notifier:emit('sender', 'read', 'message')
            notifier:emit('sender', 'write', 'message')
            dispose()
            notifier:emit('sender', 'read', 'message')
            notifier:emit('sender', 'write', 'message')

            log:debug(log_list)
            assert(notifier:get_listener_count('read') == 1)
            assert(notifier:get_listener_count('write') == 1)
            assert(#log_list == 5)
            assert(log_list[1] == "read sender read message")
            assert(log_list[2] == "read sender read message")
            assert(log_list[3] == "write sender write message")
            assert(log_list[4] == "read sender read message")
            assert(log_list[5] == "write sender write message")
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

    describe('ref', function()
        it('check type', function()
            local helper = require('helper')
            local responsive = require('lib.responsive')

            local ref = responsive.ref.create('test1')

            assert(getmetatable(ref) == responsive.ref.METATABLE)
        end)
        it('get and set', function()
            local helper = require('helper')
            local responsive = require('lib.responsive')

            local ref1 = responsive.ref.create('test1')
            local ref2 = responsive.ref.create()

            ref2.value = 'test2'

            assert(ref1.value == 'test1')
            assert(ref2.value == 'test2')
        end)
        it('add listener', function()
            local helper = require('helper')
            local responsive = require('lib.responsive')

            local ref = responsive.ref.create()
            local log_list = {}

            ref:__add_listener(responsive.EVENT.PROPERTY_READ, function(reactive, event, context)
                table.insert(log_list, event .. ' ' .. context.name)
            end)

            ref:__add_listener(responsive.EVENT.PROPERTY_CHANGED, function(reactive, event, context)
                table.insert(log_list, event .. ' ' .. context.name)
            end)

            ref.value = 'test1'
            local value = ref.value

            ref.value = 'test1_changed'
            value = ref.value

            log:debug(tools.table_to_json(log_list))

            assert(log_list[1] == 'property_changed value')
            assert(log_list[2] == 'property_read value')
            assert(log_list[3] == 'property_changed value')
            assert(log_list[4] == 'property_read value')
        end)
        it('remove listener', function()
            local helper = require('helper')
            local responsive = require('lib.responsive')

            local ref = responsive.ref.create()
            local log_list = {}

            local remove_listener = ref:__add_listener(responsive.EVENT.PROPERTY_CHANGED,
                function(responsive, event, context)
                    table.insert(log_list, event .. ' ' .. context.name)
                end)

            remove_listener()

            ref.value = 'test1'

            ref:__add_listener(responsive.EVENT.PROPERTY_CHANGED, function(responsive, event, context)
                table.insert(log_list, event .. ' ' .. context.name)
            end)

            ref.value = 'test2'

            log:debug(tools.table_to_json(log_list))
            assert(#log_list == 1)
            assert(log_list[1] == 'property_changed value')
        end)
    end)

    describe('computed', function()
        it('check type', function()
            local helper = require('helper')
            local responsive = require('lib.responsive')

            local computed = responsive.computed.create(function(self)
                return 0
            end)

            assert(getmetatable(computed) == responsive.computed.METATABLE)
        end)
        it('get and set', function()
            local helper = require('helper')
            local responsive = require('lib.responsive')

            local value = 'test1'
            local computed = responsive.computed.create(function(self)
                return value
            end, function(self, new_value)
                value = new_value
            end)

            assert(computed.value == value)

            computed.value = 'test1_changed'

            assert(computed.value == 'test1_changed')

            value = 'test1_changed_again'

            assert(computed.value == 'test1_changed_again')
        end)
        it('get only', function()
            local helper = require('helper')
            local responsive = require('lib.responsive')

            local value = 'test1'
            local computed = responsive.computed.create(function(self)
                return value
            end)

            assert(computed.value == value)

            function get_value()
                computed.value = 'test1_changed'
            end

            local status, message = pcall(get_value)
            assert(not status)
        end)
        it('add listener', function()
            local helper = require('helper')
            local responsive = require('lib.responsive')

            local value = 'test1'
            local computed = responsive.computed.create(function(self)
                return value
            end, function(self, new_value)
                value = new_value
            end)
            local log_list = {}

            computed:__add_listener(responsive.EVENT.PROPERTY_READ, function(reactive, event, context)
                table.insert(log_list, event .. ' ' .. context.name)
            end)

            computed:__add_listener(responsive.EVENT.PROPERTY_CHANGED, function(reactive, event, context)
                table.insert(log_list, event .. ' ' .. context.name)
            end)

            computed.value = 'test1_changed'
            local value_read = computed.value

            log:debug(tools.table_to_json(log_list))

            assert(#log_list == 2)
            assert(log_list[1] == 'property_changed value')
            assert(log_list[2] == 'property_read value')
        end)
        it('remove listener', function()
            local helper = require('helper')
            local responsive = require('lib.responsive')

            local value = 'test1'
            local computed = responsive.computed.create(function(self)
                return value
            end, function(self, new_value)
                value = new_value
            end)
            local log_list = {}

            local remove_listener = computed:__add_listener(responsive.EVENT.PROPERTY_CHANGED,
                function(responsive, event, context)
                    table.insert(log_list, event .. ' ' .. context.name)
                end)

            remove_listener()

            computed.value = 'test1_changed'

            computed:__add_listener(responsive.EVENT.PROPERTY_CHANGED, function(responsive, event, context)
                table.insert(log_list, event .. ' ' .. context.name)
            end)

            computed.value = 'test2'

            log:debug(tools.table_to_json(log_list))
            assert(#log_list == 1)
            assert(log_list[1] == 'property_changed value')
        end)
        it('wrap ref and computed', function()
            local helper = require('helper')
            local responsive = require('lib.responsive')

            local raw_value = 'test'
            local computed1 = responsive.computed.create(function()
                return raw_value
            end, function(self, value)
                raw_value = value
            end)
            local computed2 = responsive.computed.create(function()
                return computed1
            end, function(self, value)
                computed1.value = value
            end)
            local ref1 = responsive.ref.create(computed2)
            local ref2 = responsive.ref.create(ref1)

            assert(ref1.value == 'test')
            assert(ref2.value == 'test')
            assert(computed1.value == 'test')
            assert(computed2.value == 'test')

            ref1.value = 'test_changed1'
            assert(ref1.value == 'test_changed1')
            assert(ref2.value == 'test_changed1')
            assert(computed1.value == 'test_changed1')
            assert(computed2.value == 'test_changed1')
            assert(raw_value == 'test_changed1')

            computed2.value = 'test_changed2'
            assert(ref1.value == 'test_changed2')
            assert(ref2.value == 'test_changed2')
            assert(computed1.value == 'test_changed2')
            assert(computed2.value == 'test_changed2')
            assert(raw_value == 'test_changed2')

            computed1.value = 'test_changed3'
            assert(ref1.value == 'test_changed3')
            assert(ref2.value == 'test_changed3')
            assert(computed1.value == 'test_changed3')
            assert(computed2.value == 'test_changed3')
            assert(raw_value == 'test_changed3')

            raw_value = 'test_changed4'
            assert(ref1.value == 'test_changed4')
            assert(ref2.value == 'test_changed4')
            assert(computed1.value == 'test_changed4')
            assert(computed2.value == 'test_changed4')
            assert(raw_value == 'test_changed4')
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

            log:debug(reactive1)
            log:debug(reactive2)
            assert(reactive1.property1 == 'test1')
            assert(reactive2.property1 == 'test2')
        end)
        it('get and set integer index', function()
            local helper = require('helper')
            local responsive = require('lib.responsive')

            local reactive1 = responsive.reactive.create({'test11'})
            local reactive2 = responsive.reactive.create()

            reactive1[2] = 'test12'
            reactive2[1] = 'test21'
            reactive2[2] = 'test22'

            log:debug(reactive1)
            log:debug(reactive2)
            assert(#reactive1 == 2)
            assert(#reactive2 == 2)
            assert(reactive1[1] == 'test11')
            assert(reactive1[2] == 'test12')
            assert(reactive2[1] == 'test21')
            assert(reactive2[2] == 'test22')
        end)
        it('ipairs', function()
            local helper = require('helper')
            local responsive = require('lib.responsive')

            local reactive = responsive.reactive.create({'test1', 'test2', 'test3'})
            local log_list = {}

            for index, value in ipairs(reactive) do
                table.insert(log_list, index .. ' ' .. value)
            end

            log:debug(log_list)
            assert(#log_list == 3)
            assert(log_list[1] == '1 test1')
            assert(log_list[2] == '2 test2')
            assert(log_list[3] == '3 test3')
        end)
        it('pairs', function()
            local helper = require('helper')
            local responsive = require('lib.responsive')

            local reactive = responsive.reactive.create({'test1', 'test2', 'test3'})
            local log_list = {}

            -- TODO: 添加逻辑
        end)
        it('ref get and set', function()
            local helper = require('helper')
            local responsive = require('lib.responsive')

            local reactive1 = responsive.reactive.create({
                property1 = responsive.ref.create('test1')
            })
            local reactive2 = responsive.reactive.create()

            reactive2.property1 = responsive.ref.create('test2')

            assert(reactive1.property1 == 'test1')
            assert(reactive2.property1 == 'test2')
        end)
        it('create with bad type', function()
            local helper = require('helper')
            local responsive = require('lib.responsive')

            local status, message = pcall(responsive.reactive.create, 'test')

            assert(not status)
        end)
        it('add listener', function()
            local helper = require('helper')
            local responsive = require('lib.responsive')

            local reactive = responsive.reactive.create()
            local log_list = {}

            reactive:__add_listener(responsive.EVENT.PROPERTY_READ, function(reactive, event, context)
                table.insert(log_list, event .. ' ' .. context.name)
            end)

            reactive:__add_listener(responsive.EVENT.PROPERTY_CHANGED, function(reactive, event, context)
                table.insert(log_list, event .. ' ' .. context.name)
            end)

            reactive.property1 = 'test1'
            local property1 = reactive.property1

            log:debug(tools.table_to_json(log_list))

            assert(log_list[1] == 'property_changed property1')
            assert(log_list[2] == 'property_read property1')
        end)
        it('remove listener', function()
            local helper = require('helper')
            local responsive = require('lib.responsive')

            local reactive1 = responsive.reactive.create()
            local log_list = {}

            local remove_listener = reactive1:__add_listener(responsive.EVENT.PROPERTY_CHANGED,
                function(responsive, event, context)
                    table.insert(log_list, event .. ' ' .. context.name)
                end)

            remove_listener()

            reactive1.property1 = 'test1'

            reactive1:__add_listener(responsive.EVENT.PROPERTY_CHANGED, function(responsive, event, context)
                table.insert(log_list, event .. ' ' .. context.name)
            end)

            reactive1.property1 = 'test2'

            log:debug(tools.table_to_json(log_list))
            assert(#log_list == 1)
            assert(log_list[1] == 'property_changed property1')
        end)
    end)

    describe('unref', function()
        it('literal', function()
            local helper = require('helper')
            local responsive = require('lib.responsive')

            local value

            value = responsive.unref(999)
            assert(value == 999)
            value = responsive.unref('abc')
            assert(value == 'abc')

            local t = {}
            value = responsive.unref(t)
            assert(value == t)
        end)
        it('ref', function()
            local helper = require('helper')
            local responsive = require('lib.responsive')

            local ref = responsive.ref.create('test1')

            assert(responsive.unref(ref) == 'test1')

            local t = {}
            ref.value = t
            assert(responsive.unref(ref) == t)
        end)
        it('computed', function()
            local helper = require('helper')
            local responsive = require('lib.responsive')

            local value = 'test1'
            local computed = responsive.computed.create(function(self)
                return value
            end)

            assert(responsive.unref(computed) == 'test1')

            local t = {}
            ---@diagnostic disable-next-line: cast-local-type
            value = t
            assert(responsive.unref(computed) == t)
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
            local ref = responsive.ref.create('test1')
            local log_list = {}

            watch:add_listener(responsive.EVENT.PROPERTY_CHANGED, function(sender, event, context)
                table.insert(log_list, sender.__id .. ' ' .. event .. ' ' .. context.name)
            end)
            watch:record()
            local property1 = reactive.property1
            property1 = reactive.property1
            local value = responsive.unref(ref)
            value = responsive.unref(ref)
            watch:stop()

            assert(#log_list == 0)
            reactive.property1 = 'test1_changed'
            ref.value = 'test1_changed'

            log:debug(log_list)

            assert(responsive.responsive_global_notifier:get_listener_count(responsive.EVENT.PROPERTY_READ) == 0)
            assert(reactive.__notifier:get_listener_count(responsive.EVENT.PROPERTY_CHANGED) == 1)
            assert(#log_list == 2)
            assert(log_list[1] == reactive.__id .. ' property_changed property1')
            assert(log_list[2] == ref.__id .. ' property_changed value')
        end)
        it('reset', function()
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
            watch:reset()

            reactive.property1 = 'test1_changed'
            log:debug(tools.table_to_json(log_list))

            assert(reactive.__notifier:get_listener_count(responsive.EVENT.PROPERTY_CHANGED) == 0)
            assert(#log_list == 0)
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
        it('reactive dirty', function()
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
        it('computed dirty', function()
            local helper = require('helper')
            local responsive = require('lib.responsive')

            local computed = responsive.computed.create(function()
                return {
                    value = 'test1'
                }
            end)
            local binding = responsive.binding.create(computed, 'value', responsive.binding.MODE.PULL)

            assert(binding:dirty())
            assert(binding:get() == 'test1')
        end)
    end)
end)

describe('ui', function()
    describe('__propertydescriptormap', function()
        it('check type', function()
            local helper = require('helper')
            local ui = require('lib.ui')

            local property_descriptor_map = ui.__propertydescriptormap.create({})

            assert(getmetatable(property_descriptor_map) == ui.__propertydescriptormap.METATABLE)
        end)
        it('const value', function()
            local helper = require('helper')
            local ui = require('lib.ui')

            local property_descriptor_map = ui.__propertydescriptormap.create({
                property1 = 'test1'
            })

            property_descriptor_map:__ensure_descriptor_map()

            log:debug(property_descriptor_map.__descriptor_map)
            assert(property_descriptor_map:get_descriptor('property1').type == ui.__propertydescriptormap.TYPE.CONST)
            assert(property_descriptor_map:get_descriptor('property1').value == 'test1')
        end)
        it('dynamic value', function()
            local helper = require('helper')
            local ui = require('lib.ui')

            local property_descriptor_map = ui.__propertydescriptormap.create({
                [':property1'] = 'test1',
                ['v-bind:property2'] = 'test2'
            })

            property_descriptor_map:__ensure_descriptor_map()

            log:debug(property_descriptor_map.__descriptor_map)
            assert(property_descriptor_map:get_descriptor('property1').type == ui.__propertydescriptormap.TYPE.DYNAMIC)
            assert(property_descriptor_map:get_descriptor('property1').value == 'test1')
            assert(property_descriptor_map:get_descriptor('property2').type == ui.__propertydescriptormap.TYPE.DYNAMIC)
            assert(property_descriptor_map:get_descriptor('property2').value == 'test2')
        end)
        it('model value', function()
            local helper = require('helper')
            local ui = require('lib.ui')

            local property_descriptor_map = ui.__propertydescriptormap.create({
                ['v-model:property1'] = 'test1'
            })

            property_descriptor_map:__ensure_descriptor_map()

            log:debug(property_descriptor_map.__descriptor_map)
            assert(property_descriptor_map:get_descriptor('property1').type == ui.__propertydescriptormap.TYPE.MODEL)
            assert(property_descriptor_map:get_descriptor('property1').value == 'test1')
        end)
        it('callback value', function()
            local helper = require('helper')
            local ui = require('lib.ui')

            local property_descriptor_map = ui.__propertydescriptormap.create({
                ['@property1'] = 'test1',
                ['v-on:property2'] = 'test2'
            })

            property_descriptor_map:__ensure_descriptor_map()

            log:debug(property_descriptor_map.__descriptor_map)
            assert(property_descriptor_map:get_descriptor('property1').type == ui.__propertydescriptormap.TYPE.CALLBACK)
            assert(property_descriptor_map:get_descriptor('property1').value == 'test1')
            assert(property_descriptor_map:get_descriptor('property2').type == ui.__propertydescriptormap.TYPE.CALLBACK)
            assert(property_descriptor_map:get_descriptor('property2').value == 'test2')
        end)
        it('slot value', function()
            local helper = require('helper')
            local ui = require('lib.ui')

            local property_descriptor_map = ui.__propertydescriptormap.create({
                ['#property1'] = 'test1',
                ['v-slot:property2'] = 'test2'
            })

            property_descriptor_map:__ensure_descriptor_map()

            log:debug(property_descriptor_map.__descriptor_map)
            assert(property_descriptor_map:get_descriptor('property1').type == ui.__propertydescriptormap.TYPE.SLOT)
            assert(property_descriptor_map:get_descriptor('property1').value == 'test1')
            assert(property_descriptor_map:get_descriptor('property2').type == ui.__propertydescriptormap.TYPE.SLOT)
            assert(property_descriptor_map:get_descriptor('property2').value == 'test2')
        end)
    end)

    describe('execution', function()
        it('one binding', function()
            local helper = require('helper')
            local responsive = require('lib.responsive')
            local ui = require('lib.ui')

            local data = responsive.reactive.create({
                property1 = 'test1',
                property2 = 'test2'
            })
            local log_list = {}

            local binding = responsive.binding.create(data, 'property1', responsive.binding.MODE.PULL)
            local execution = ui.execution.create_value_execution(binding, function(execution, value)
                table.insert(log_list, 'process property1 ' .. value)
            end)

            assert(execution:dirty())
            execution:process()
            assert(not execution:dirty())
            execution:process()
            assert(not execution:dirty())

            data.property1 = 'test1_changed'
            assert(execution:dirty())
            execution:process()
            assert(not execution:dirty())
            execution:process()
            assert(not execution:dirty())

            log:debug(tools.table_to_json(log_list))
            assert(#log_list == 2)
            assert(log_list[1] == 'process property1 test1')
            assert(log_list[2] == 'process property1 test1_changed')
        end)
        it('bidirection binding', function()
            local helper = require('helper')
            local responsive = require('lib.responsive')
            local ui = require('lib.ui')

            local data = responsive.reactive.create({
                property1 = 'test1',
                property2 = {
                    property3 = 'test3'
                }
            })
            local log_list = {}
            local binding = responsive.binding
                                .create(data, 'property2.property3', responsive.binding.MODE.PULL_AND_PUSH)
            local execution = ui.execution.create_value_execution(binding, function(execution, value)
                table.insert(log_list, 'process property2.property3 ' .. value)
            end)

            execution:process()
            assert(#log_list == 1)

            ---@diagnostic disable-next-line: need-check-nil
            binding:set('test3_changed')
            execution:process()
            assert(#log_list == 1)
            assert(data.property2.property3 == 'test3_changed')
        end)
        it('dispose', function()
            -- TODO: 添加逻辑
        end)
    end)

    describe('vstyle', function()
        it('const value', function()
            local helper = require('helper')
            local ui = require('lib.ui')

            local element = helper.create_gui_element('frame')
            local vnode = ui.vnode.create({
                template = {
                    type = 'frame',
                    style = {
                        width = 400,
                        height = 500
                    }
                }
            })

            vnode:__setup()
            vnode:__mount(element)
            vnode:__update()

            log:debug(element)
            assert(element.style.width == 400)
            assert(element.style.height == 500)
        end)
        it('pull binding', function()
            local helper = require('helper')
            local ui = require('lib.ui')
            local responsive = require('lib.responsive')

            local element = helper.create_gui_element('frame')
            local data = responsive.reactive.create({
                width = 400
            })
            local vnode = ui.vnode.create({
                template = {
                    type = 'frame',
                    style = {
                        [':width'] = 'width'
                    }
                },
                data = data
            })

            vnode:__setup()
            vnode:__mount(element)
            vnode:__update()

            log:debug(element)
            assert(element.style.width == 400)

            data.width = 500
            assert(element.style.width == 400)

            vnode:__update()

            log:debug(element)
            assert(element.style.width == 500)
        end)
    end)

    describe('vnode', function()
        it('check type', function()
            local helper = require('helper')
            local ui = require('lib.ui')

            local element = helper.create_gui_element('frame')
            local vnode = ui.vnode.create({
                template = {
                    type = 'frame'
                }
            })

            assert(getmetatable(vnode) == ui.vnode.METATABLE)
        end)
        -- TODO: virtual 节点不能是根节点
        -- TODO: virtual 节点不能设置 element
        it('const value', function()
            local helper = require('helper')
            local ui = require('lib.ui')

            local element = helper.create_gui_element('frame')
            local vnode = ui.vnode.create({
                template = {
                    type = 'frame',
                    caption = 'test',
                    enabled = false
                }
            })

            vnode:__setup()
            vnode:__mount(element)
            vnode:__update()

            log:debug(element)
            assert(element.caption == 'test')
            assert(element.enabled == false)
        end)
        it('pull binding', function()
            local helper = require('helper')
            local ui = require('lib.ui')
            local responsive = require('lib.responsive')

            local element = helper.create_gui_element('frame')
            local data = responsive.reactive.create({
                property1 = 'test1'
            })
            local vnode = ui.vnode.create({
                template = {
                    type = 'frame',
                    [':caption'] = 'property1'
                },
                data = data
            })

            vnode:__setup()
            vnode:__mount(element)
            vnode:__update()

            log:debug(element)
            assert(element.caption == 'test1')

            data.property1 = 'test1_changed1'
            assert(element.caption == 'test1')

            vnode:__update()
            assert(element.caption == 'test1_changed1')

            data.property1 = 'test1_changed2'
            vnode:__update()
            assert(element.caption == 'test1_changed2')

            data.property1 = 'test1_changed3'
            vnode:__update()
            assert(element.caption == 'test1_changed3')
        end)
        it('invoke event handler', function()
            local helper = require('helper')
            local ui = require('lib.ui')
            local responsive = require('lib.responsive')

            local log_list = {}
            local element = helper.create_gui_element('frame')
            local data = responsive.reactive.create({
                property1 = 'test1',
                onclick1 = function(vnode, name, event)
                    table.insert(log_list, string.format('%s %s %s', vnode.__id, name, event))
                end
            })
            local vnode = ui.vnode.create({
                template = {
                    type = 'frame',
                    ['@click'] = 'onclick1'
                },
                data = data
            })

            vnode:__setup()
            vnode:__mount(element)
            vnode:__update()

            log:debug(element)
            log:debug(log_list)
            vnode:__invoke_event_handler('click', 'event')
            assert(#log_list == 1)
            assert(log_list[1] == vnode.__id .. ' click event')
        end)
        it('push binding', function()
            -- TODO: 添加逻辑
        end)
        describe('children', function()
            it('initial', function()
                local helper = require('helper')
                local ui = require('lib.ui')
                local responsive = require('lib.responsive')

                local element = helper.create_gui_element('frame')
                local data = responsive.reactive.create({
                    property1 = 'test1',
                    property2 = {
                        property3 = 'test3'
                    }
                })
                local vnode = ui.vnode.create({
                    template = {
                        type = 'frame',
                        [':caption'] = 'property1',
                        children = {{
                            type = 'button',
                            [':caption'] = 'property1'
                        }, {
                            type = 'checkbox',
                            [':caption'] = 'property2.property3'
                        }}
                    },
                    data = data
                })

                vnode:__setup()
                vnode:__mount(element)
                vnode:__update()

                log:debug(helper.clone_table(element, helper.drop_vnode_ref))

                assert(ui.vnode.get_vnode_by_element(element) == vnode)
                assert(#element.children == 2)
                assert(element.children[1].type == 'button')
                assert(element.children[1].caption == 'test1')
                assert(ui.vnode.get_vnode_by_element(element.children[1]) == vnode.__effective_child_vnode_list[1][1])
                assert(element.children[1] == vnode.__effective_child_vnode_list[1][1].__element)
                assert(element.children[2].type == 'checkbox')
                assert(element.children[2].caption == 'test3')
                assert(ui.vnode.get_vnode_by_element(element.children[2]) == vnode.__effective_child_vnode_list[2][1])
                assert(element.children[2] == vnode.__effective_child_vnode_list[2][1].__element)
            end)
            it('change property', function()
                local helper = require('helper')
                local ui = require('lib.ui')
                local responsive = require('lib.responsive')

                local element = helper.create_gui_element('frame')
                local data = responsive.reactive.create({
                    property1 = 'test1',
                    property2 = {
                        property3 = 'test3'
                    }
                })
                local vnode = ui.vnode.create({
                    template = {
                        type = 'frame',
                        [':caption'] = 'property1',
                        children = {{
                            type = 'button',
                            [':caption'] = 'property1'
                        }, {
                            type = 'button',
                            [':caption'] = 'property1'
                        }, {
                            type = 'checkbox',
                            [':caption'] = 'property2.property3'
                        }}
                    },
                    data = data
                })

                vnode:__setup()
                vnode:__mount(element)
                vnode:__update()

                data.property1 = 'test1_changed1'
                data.property2.property3 = 'test3_changed1'

                log:debug(helper.clone_table(element, helper.drop_vnode_ref))
                assert(#element.children == 3)
                assert(element.children[1].caption == 'test1')
                assert(element.children[2].caption == 'test1')
                assert(element.children[3].caption == 'test3')

                vnode:__update()
                log:debug(helper.clone_table(element, helper.drop_vnode_ref))
                assert(element.children[1].caption == 'test1_changed1')
                assert(element.children[2].caption == 'test1_changed1')
                assert(element.children[3].caption == 'test3_changed1')

                data.property1 = 'test1_changed2'
                data.property2.property3 = 'test3_changed2'
                vnode:__update()
                log:debug(helper.clone_table(element, helper.drop_vnode_ref))
                assert(element.children[1].caption == 'test1_changed2')
                assert(element.children[2].caption == 'test1_changed2')
                assert(element.children[3].caption == 'test3_changed2')

                data.property1 = 'test1_changed3'
                data.property2.property3 = 'test3_changed3'
                vnode:__update()
                log:debug(helper.clone_table(element, helper.drop_vnode_ref))
                assert(element.children[1].caption == 'test1_changed3')
                assert(element.children[2].caption == 'test1_changed3')
                assert(element.children[3].caption == 'test3_changed3')
            end)
            it('child component', function()
                local helper = require('helper')
                local ui = require('lib.ui')

                local element = helper.create_gui_element('frame')
                helper.clear_component_factory()
                ui.component.register_component_factory('child_component', function(self, definition)
                    return ui.vnode.create({
                        template = {
                            type = 'button',
                            caption = 'test'
                        },
                        parent = definition.parent,
                        data = definition.data
                    })
                end)
                local vnode = ui.vnode.create({
                    template = {
                        type = 'frame',
                        children = {{
                            type = 'component',
                            name = 'child_component'
                        }, {
                            type = 'component',
                            name = 'child_component'
                        }}
                    }
                })

                vnode:__setup()
                vnode:__mount(element)
                vnode:__update()

                log:debug(helper.clone_table(element, helper.drop_vnode_ref))
                assert(#element.children == 2)
                assert(element.children[1].caption == 'test')
                assert(element.children[2].caption == 'test')
            end)
            it('child component with property binding', function()
                local helper = require('helper')
                local ui = require('lib.ui')
                local responsive = require('lib.responsive')

                local element = helper.create_gui_element('frame')
                helper.clear_component_factory()
                ui.component.register_component_factory('child_component', function(self, definition)
                    return ui.vnode.create({
                        template = {
                            type = 'button',
                            [':caption'] = 'caption'
                        },
                        parent = definition.parent,
                        data = definition.data
                    })
                end)
                local data = responsive.reactive.create({
                    property1 = 'test1',
                    property2 = {
                        property3 = 'test3'
                    }
                })
                local vnode = ui.vnode.create({
                    template = {
                        type = 'frame',
                        [':caption'] = 'property1',
                        children = {{
                            type = 'component',
                            name = 'child_component',
                            data = {
                                caption = 'test2'
                            }
                        }, {
                            type = 'component',
                            name = 'child_component',
                            data = {
                                caption = 'test3'
                            }
                        }}
                    },
                    data = data
                })

                vnode:__setup()
                vnode:__mount(element)
                vnode:__update()

                log:debug(helper.clone_table(element, helper.drop_vnode_ref))
                assert(element.caption == 'test1')
                assert(#element.children == 2)
                assert(element.children[1].caption == 'test2')
                assert(element.children[2].caption == 'test3')
            end)
            it('child component with data binding', function()
                local helper = require('helper')
                local ui = require('lib.ui')
                local responsive = require('lib.responsive')

                local element = helper.create_gui_element('frame')
                helper.clear_component_factory()
                ui.component.register_component_factory('child_component', function(self, definition)
                    return ui.vnode.create({
                        template = {
                            type = 'button',
                            [':caption'] = 'caption'
                        },
                        parent = definition.parent,
                        data = definition.data
                    })
                end)
                local data = responsive.reactive.create({
                    property1 = 'test1',
                    property2 = {
                        caption = 'test2'
                    },
                    property3 = {
                        caption = 'test3'
                    }
                })
                local vnode = ui.vnode.create({
                    template = {
                        type = 'frame',
                        [':caption'] = 'property1',
                        children = {{
                            type = 'component',
                            name = 'child_component',
                            [':data'] = 'property2'
                        }, {
                            type = 'component',
                            name = 'child_component',
                            [':data'] = 'property3'
                        }}
                    },
                    data = data
                })

                vnode:__setup()
                vnode:__mount(element)
                vnode:__update()

                log:debug(helper.clone_table(element, helper.drop_vnode_ref))
                assert(element.caption == 'test1')
                assert(#element.children == 2)
                assert(element.children[1].caption == 'test2')
                assert(element.children[2].caption == 'test3')

                data.property2.caption = 'test2_changed'
                data.property3.caption = 'test3_changed'

                assert(element.caption == 'test1')
                assert(#element.children == 2)
                assert(element.children[1].caption == 'test2')
                assert(element.children[2].caption == 'test3')

                vnode:__update()

                log:debug(helper.clone_table(element, helper.drop_vnode_ref))
                assert(element.caption == 'test1')
                assert(#element.children == 2)
                assert(element.children[1].caption == 'test2_changed')
                assert(element.children[2].caption == 'test3_changed')

                data.property2 = {
                    caption = 'test2_changed2'
                }
                data.property3 = {
                    caption = 'test3_changed2'
                }

                assert(element.caption == 'test1')
                assert(#element.children == 2)
                assert(element.children[1].caption == 'test2_changed')
                assert(element.children[2].caption == 'test3_changed')

                vnode:__update()

                log:debug(helper.clone_table(element, helper.drop_vnode_ref))
                assert(element.caption == 'test1')
                assert(#element.children == 2)
                assert(element.children[1].caption == 'test2_changed2')
                assert(element.children[2].caption == 'test3_changed2')
            end)
        end)
        it('dispose', function()
            -- TODO: 添加逻辑
        end)
    end)

    describe('component', function()
        it('register and get', function()
            local helper = require('helper')
            local ui = require('lib.ui')

            local component_get = function()
                return 'test_component'
            end

            ui.component.register_component_factory('test', component_get)

            local component_factory = ui.component.get_factory():get_component_factory('test')

            assert(component_factory.name == 'test')
            assert(component_factory:get() == 'test_component')
        end)
    end)
end)
