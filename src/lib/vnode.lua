local tools = require('lib.tools')
local unique_id = require('lib.unique_id')

local M = {}

M.vstyle = {}
M.vstyle.METATABLE = {
    __type = 'kvstyle',
    __index = function(vstyle, name)
        if string.sub(name, 1, 2) == '__' then
            return rawget(vstyle, name)
        else
            return rawget(vstyle, '__element').style[name]
        end
    end,
    __newindex = function(vstyle, name, value)
        rawget(vstyle, '__vnode').__element.style[name] = value
        rawset(vstyle, name, value)
    end
}
M.vstyle.PROTOTYPE = {}
setmetatable(M.vstyle.PROTOTYPE, M.vstyle.METATABLE)

M.vstyle.create = function(vnode)
    return tools.inherit_prototype(M.vnode.PROTOTYPE, {
        __id = unique_id.generate_unique('vstyle'),
        __vnode = vnode
    })
end

M.vnode = {}
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
        rawget(vnode, '__set_' .. name)(vnode, value)
    end
}
M.vnode.PROTOTYPE = {
    __get_type = function(self)
        return rawget(self, '__element').type
    end
}
setmetatable(M.vnode.PROTOTYPE, M.vnode.METATABLE)

M.vnode.create = function(element)
    local vnode = tools.inherit_prototype(M.vnode.PROTOTYPE, {
        __id = unique_id.generate_unique('vnode'),
        __element = element
    })

    vnode.style = M.style.create(vnode)

    return vnode
end

return M
