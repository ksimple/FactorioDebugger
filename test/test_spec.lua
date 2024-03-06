local current_file_path = debug.getinfo(1).source:sub(2) -- 去掉路径前面的 '@'
print(current_file_path)
local path_separator = package.config:sub(1, 1)          -- 获取路径分隔符，Windows 是 '\'，Unix 是 '/'
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

            ref:__add_listener(responsive.EVENT.PROPERTY_READ, function(reactive, event, name, old_value, new_value)
                table.insert(log_list, event .. ' ' .. name)
            end)

            ref:__add_listener(responsive.EVENT.PROPERTY_CHANGED, function(reactive, event, name, old_value, new_value)
                table.insert(log_list, event .. ' ' .. name)
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
                function(responsive, event, name, old_value, new_value)
                    table.insert(log_list, event .. ' ' .. name)
                end)

            remove_listener()

            ref.value = 'test1'

            ref:__add_listener(responsive.EVENT.PROPERTY_CHANGED,
                function(responsive, event, name, old_value, new_value)
                    table.insert(log_list, event .. ' ' .. name)
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

            computed:__add_listener(responsive.EVENT.PROPERTY_READ,
                function(reactive, event, name, old_value, new_value)
                    table.insert(log_list, event .. ' ' .. name)
                end)

            computed:__add_listener(responsive.EVENT.PROPERTY_CHANGED,
                function(reactive, event, name, old_value, new_value)
                    table.insert(log_list, event .. ' ' .. name)
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
                function(responsive, event, name, old_value, new_value)
                    table.insert(log_list, event .. ' ' .. name)
                end)

            remove_listener()

            computed.value = 'test1_changed'

            computed:__add_listener(responsive.EVENT.PROPERTY_CHANGED,
                function(responsive, event, name, old_value, new_value)
                    table.insert(log_list, event .. ' ' .. name)
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

            assert(reactive1.property1 == 'test1')
            assert(reactive2.property1 == 'test2')
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

            watch:add_listener(responsive.EVENT.PROPERTY_CHANGED, function(sender, event, name, old_value, new_value)
                table.insert(log_list,
                    sender.__id .. ' ' .. event .. ' ' .. name .. ' ' .. tostring(old_value) .. ' ' ..
                    tostring(new_value))
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

            log:debug(tools.table_to_json(log_list))

            assert(responsive.responsive_global_notifier:get_listener_count(responsive.EVENT.PROPERTY_READ) == 0)
            assert(reactive.__notifier:get_listener_count(responsive.EVENT.PROPERTY_CHANGED) == 1)
            assert(#log_list == 2)
            assert(log_list[1] == reactive.__id .. ' property_changed property1 test1 test1_changed')
            assert(log_list[2] == ref.__id .. ' property_changed value test1 test1_changed')
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
        it('wrong property name', function()
            local helper = require('helper')
            local ui = require('lib.ui')

            local element = helper.create_gui_element('frame')
            local vnode = ui.vnode.create({
                template = {
                    type = 'frame',
                    catpion = 'test'
                }
            })

            local error, message = pcall(vnode.__setup, vnode)

            log:debug(tostring(error) .. ', ' .. message)
            assert(not error)
            assert(message:find('catpion') > 0)
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
                        children = { {
                            type = 'button',
                            [':caption'] = 'property1'
                        }, {
                            type = 'checkbox',
                            [':caption'] = 'property2.property3'
                        } }
                    },
                    data = data
                })

                vnode:__setup()
                vnode:__mount(element)
                vnode:__update()

                log:debug(helper.clone_table(element, helper.drop_vnode_ref))
                assert(#element.children == 2)
                assert(#ui.vnode.element_key_to_vnode_map)
                assert(element.children[1].type == 'button')
                assert(element.children[1].caption == 'test1')
                assert(ui.vnode.get_vnode_by_element(element.children[1]) == vnode.__effective_child_vnode_list[1])
                assert(element.children[1] == vnode.__effective_child_vnode_list[1].__element)
                assert(element.children[2].type == 'checkbox')
                assert(element.children[2].caption == 'test3')
                assert(ui.vnode.get_vnode_by_element(element.children[2]) == vnode.__effective_child_vnode_list[2])
                assert(element.children[2] == vnode.__effective_child_vnode_list[2].__element)
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
                        children = { {
                            type = 'button',
                            [':caption'] = 'property1'
                        }, {
                            type = 'button',
                            [':caption'] = 'property1'
                        }, {
                            type = 'checkbox',
                            [':caption'] = 'property2.property3'
                        } }
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
        end)
        it('dispose', function()
            -- TODO: 添加逻辑
        end)
    end)

    describe('component', function()
        -- TODO: 增加测试用例
    end)
end)
