cimport clua
cimport cpython


_typename = {
    clua.LUA_TNIL: 'nil',
    clua.LUA_TBOOLEAN: 'boolean',
    clua.LUA_TLIGHTUSERDATA: 'lightuserdata',
    clua.LUA_TNUMBER: 'number',
    clua.LUA_TTABLE: 'table',
    clua.LUA_TFUNCTION: 'function',
    clua.LUA_TUSERDATA: 'userdata',
    clua.LUA_TTHREAD: 'thread'
}


# Lua wrapper for Python objects
ctypedef struct PythonData:
    cpython.PyObject *pyobj
    int attrindex


cdef void new_PythonData(clua.lua_State *L, object obj, int attrindex):
    """
    Push a new Lua userdata for the given Python object onto the stack
    (obj's refcount is incremented).
    """
    cdef PythonData *data
    data = <PythonData *>clua.lua_newuserdata(L, sizeof(PythonData))
    data.pyobj = <cpython.PyObject *>obj
    data.attrindex = attrindex
    cpython.Py_INCREF(obj)
    clua.luaL_setmetatable(L, "lupy_Python")


cdef PythonData *check_PythonData(clua.lua_State *L, int index):
    """
    Return a pointer to the PythonData referred to at the given index on the
    stack, or NULL if there is none such.
    """
    return <PythonData *>clua.luaL_testudata(L, index, "lupy_Python")


class LuaError(Exception):
    pass


cdef int check_status(clua.lua_State *L, int status) except -1:
    """
    Raise a Python exception if the status was not LUA_OK.
    Otherwise, do nothing
    """
    if status != clua.LUA_OK:
        error = lua2python_pop(L)
        if not isinstance(error, Exception):
            error = LuaError(error)
        raise error
    return 0


cdef object lua2python(clua.lua_State *L, int index):
    """
    Return a Python version of the Lua object at a given index on the stack.
    """
    cdef int type
    cdef PythonData *data
    type = clua.lua_type(L, index)
    if type == clua.LUA_TNONE:
        raise IndexError
    elif type == clua.LUA_TNIL:
        return None
    elif type == clua.LUA_TNUMBER:
        fval = clua.lua_tonumber(L, index)
        ival = int(fval)
        if ival == fval:
            return ival
        return fval
    elif type == clua.LUA_TBOOLEAN:
        return bool(clua.lua_toboolean(L, index))
    elif type == clua.LUA_TSTRING:
        return clua.lua_tostring(L, index)
    elif type == clua.LUA_TTABLE or type == clua.LUA_TFUNCTION:
        clua.lua_pushvalue(L, index)
        return new_Object(L)
    elif type == clua.LUA_TUSERDATA:
        data = check_PythonData(L, index)
        if data == NULL:
            clua.lua_pushvalue(L, index)
            return new_Object(L)
        return <object>data.pyobj


cdef object lua2python_pop(clua.lua_State *L):
    """
    Return a Python version of the Lua object at the top of the stack and pop
    the stack.
    """
    result = lua2python(L, -1)
    clua.lua_pop(L, 1)
    return result


cdef void python2lua(clua.lua_State *L, object obj):
    """
    Push a Lua version of the given Python object onto the stack.
    """
    # Using type(obj) here to work around what seems to be a bug in the Cython
    # implementation of isinstance() for objects whose class implements
    # __getattribute__()
    if type(obj) is Object:
        Object_pushtostack(<Object>obj)
        if L is not (<Object>obj)._L:
            clua.lua_xmove((<Object>obj)._L, L, 1)
    elif obj is None:
        clua.lua_pushnil(L)
    elif isinstance(obj, bool):
        clua.lua_pushboolean(L, obj)
    elif isinstance(obj, int):
        clua.lua_pushinteger(L, obj)
    elif isinstance(obj, float):
        clua.lua_pushnumber(L, obj)
    elif isinstance(obj, basestring):
        clua.lua_pushstring(L, obj)
    else:
        new_PythonData(L, obj, not isinstance(obj, (list, tuple, dict)))


cdef void python2lua_rec(clua.lua_State *L, object obj):
    cdef int t
    cdef int i
    if type(obj) is Object:
        python2lua(L, obj)
    elif isinstance(obj, (list, tuple)):
        clua.lua_createtable(L, <int>len(obj), 0)
        t = clua.lua_gettop(L)
        for i, x in enumerate(obj, 1):
            python2lua_rec(L, x)
            clua.lua_rawseti(L, t, i)
    elif isinstance(obj, dict):
        clua.lua_createtable(L, 0, <int>len(obj))
        t = clua.lua_gettop(L)
        for k, v in obj.iteritems():
            python2lua_rec(L, k)
            python2lua_rec(L, v)
            clua.lua_rawset(L, t)
    else:
        python2lua(L, obj)


#
# Python object wrapper for Lua:
#     Python metatable methods
#

cdef unwrap_data(clua.lua_State *L, int index):
    cdef PythonData *data
    data = <PythonData *>clua.lua_touserdata(L, index)
    return <object>data.pyobj


cdef int except2error(clua.lua_State *L, object e):
    python2lua(L, e)
    return clua.lua_error(L)


cdef int py__tostring(clua.lua_State *L):
    obj = unwrap_data(L, 1)
    s = str(obj)
    clua.lua_pushstring(L, s)
    return 1


cdef int py__index(clua.lua_State *L):
    cdef PythonData *data
    data = <PythonData *>clua.lua_touserdata(L, 1)
    obj = <object>data.pyobj
    index = lua2python(L, 2)
    try:
        if data.attrindex:
            val = getattr(obj, index)
        else:
            val = obj[index]
    except Exception, e:
        return except2error(L, e)
    python2lua(L, val)
    return 1


cdef int py__newindex(clua.lua_State *L):
    cdef PythonData *data
    data = <PythonData *>clua.lua_touserdata(L, 1)
    obj = <object>data.pyobj
    index = lua2python(L, 2)
    value = lua2python(L, 3)
    try:
        if data.attrindex:
            setattr(obj, index, value)
        else:
            obj[index] = value
    except Exception, e:
        return except2error(L, e)
    return 0


cdef int py__call(clua.lua_State *L):
    cdef int i
    obj = unwrap_data(L, 1)
    args = []
    try:
        for i in range(2, clua.lua_gettop(L) + 1):
            args.append(lua2python(L, i))
        result = obj(*args)
        python2lua(L, result)
    except Exception, e:
        return except2error(L, e)
    return 1


cdef int py__add(clua.lua_State *L):
    obj = unwrap_data(L, 1)
    other = lua2python(L, 2)
    try:
        result = obj + other
    except Exception, e:
        return except2error(L, e)
    python2lua(L, result)
    return 1


cdef int py__sub(clua.lua_State *L):
    obj = unwrap_data(L, 1)
    other = lua2python(L, 2)
    try:
        result = obj - other
    except Exception, e:
        return except2error(L, e)
    python2lua(L, result)
    return 1


cdef int py__mul(clua.lua_State *L):
    obj = unwrap_data(L, 1)
    other = lua2python(L, 2)
    try:
        result = obj * other
    except Exception, e:
        return except2error(L, e)
    python2lua(L, result)
    return 1


cdef int py__div(clua.lua_State *L):
    obj = unwrap_data(L, 1)
    other = lua2python(L, 2)
    try:
        result = obj / other
    except Exception, e:
        return except2error(L, e)
    python2lua(L, result)
    return 1


cdef int py__pow(clua.lua_State *L):
    obj = unwrap_data(L, 1)
    other = lua2python(L, 2)
    try:
        result = obj ** other
    except Exception, e:
        return except2error(L, e)
    python2lua(L, result)
    return 1


cdef int py__mod(clua.lua_State *L):
    obj = unwrap_data(L, 1)
    other = lua2python(L, 2)
    try:
        result = obj % other
    except Exception, e:
        return except2error(L, e)
    python2lua(L, result)
    return 1


cdef int py__unm(clua.lua_State *L):
    obj = unwrap_data(L, 1)
    try:
        result = -obj
    except Exception, e:
        return except2error(L, e)
    python2lua(L, result)
    return 1


cdef int py__gc(clua.lua_State *L):
    obj = unwrap_data(L, 1)
    cpython.Py_DECREF(obj)
    return 0


cdef int py__len(clua.lua_State *L):
    obj = unwrap_data(L, 1)
    try:
        result = len(obj)
    except Exception, e:
        return except2error(L, e)
    python2lua(L, result)
    return 1


cdef int py__eq(clua.lua_State *L):
    obj = unwrap_data(L, 1)
    other = lua2python(L, 2)
    try:
        result = obj == other
    except Exception, e:
        return except2error(L, e)
    python2lua(L, result)
    return 1

    
cdef int py__lt(clua.lua_State *L):
    obj = unwrap_data(L, 1)
    other = lua2python(L, 2)
    try:
        result = obj < other
    except Exception, e:
        return except2error(L, e)
    python2lua(L, result)
    return 1


cdef int py__le(clua.lua_State *L):
    obj = unwrap_data(L, 1)
    other = lua2python(L, 2)
    try:
        result = obj <= other
    except Exception, e:
        return except2error(L, e)
    python2lua(L, result)
    return 1


cdef int ipairs_f(clua.lua_State *L):
    it = lua2python(L, 1)
    val = lua2python(L, 2)
    try:
        next = it.next()
    except StopIteration:
        return 0
    except Exception, e:
        return except2error(L, e)
    python2lua(L, val + 1)
    python2lua(L, next)
    return 2


cdef int py__ipairs(clua.lua_State *L):
    obj = unwrap_data(L, 1)
    try:
        it = iter(obj)
    except Exception, e:
        return except2error(L, e)
    clua.lua_pushcfunction(L, ipairs_f)
    python2lua(L, it)
    python2lua(L, 0)
    return 3


#
# Lua object wrapper for Python
#

cdef class Object:
    cdef int _ref
    cdef clua.lua_State *_L
    # I'm not using this at the moment, but it is useful for refcounting and
    # it may come handy in the future
    cdef object _state

    def __init__(self):
        raise TypeError("This class cannot be instanciated from Python")

    def __dealloc__(self):
        clua.luaL_unref(self._L, clua.LUA_REGISTRYINDEX, self._ref)
    
    def __repr__(self):
        return "<Lua Object %s>" % self

    def __len__(self):
        cdef int len
        Object_pushtostack(self)
        clua.lua_len(self._L, -1)
        len = lua2python(self._L, -1)
        clua.lua_pop(self._L, 2)
        return len

    def __richcmp__(self, other, int richop):
        if richop == 0:
            return Object_compare(self, other, clua.LUA_OPLT)
        elif richop == 1:
            return Object_compare(self, other, clua.LUA_OPLE)
        elif richop == 2:
            return Object_compare(self, other, clua.LUA_OPEQ)
        elif richop == 3:
            return not Object_compare(self, other, clua.LUA_OPEQ)
        elif richop == 4:
            return not Object_compare(self, other, clua.LUA_OPLE)
        elif richop == 5:
            return not Object_compare(self, other, clua.LUA_OPLT)

    
    def __add__(self, other):
        return Object_arith2(self, other, clua.LUA_OPADD)

    def __sub__(self, other):
        return Object_arith2(self, other, clua.LUA_OPSUB)

    def __mul__(self, other):
        return Object_arith2(self, other, clua.LUA_OPMUL)

    def __div__(self, other):
        return Object_arith2(self, other, clua.LUA_OPDIV)

    def __mod__(self, other):
        return Object_arith2(self, other, clua.LUA_OPMOD)

    def __pow__(self, other, mod):
        if mod is not None:
            raise TypeError("Lua power does not support third argument")
        return Object_arith2(self, other, clua.LUA_OPPOW)

    def __neg__(self):
        Object_pushtostack(self)
        clua.lua_arith(self._L, clua.LUA_OPUNM)
        return lua2python_pop(self._L)

    def __str__(self):
        clua.lua_getglobal(self._L, "tostring")
        Object_pushtostack(self)
        check_status(self._L, clua.lua_pcall(self._L, 1, 1, 0))
        return lua2python_pop(self._L)

    def __getitem__(self, key):
        Object_pushtostack(self)
        python2lua(self._L, key)
        clua.lua_gettable(self._L, -2)
        val = lua2python_pop(self._L)
        clua.lua_pop(self._L, 1)
        return val

    def __setitem__(self, key, val):
        Object_pushtostack(self)
        python2lua(self._L, key)
        python2lua(self._L, val)
        clua.lua_settable(self._L, -3)
        clua.lua_pop(self._L, 1)

    def __iter__(self):
        # We need a new thread because we can't leave stuff on the main stack
        cdef clua.lua_State *S = clua.lua_newthread(self._L)
        s = new_Object(self._L)
        Object_pushtostack(self)
        clua.lua_xmove(self._L, S, 1)
        cdef int i
        for i in range(1, len(self) + 1):
            clua.lua_pushinteger(S, i)
            clua.lua_gettable(S, -2)
            yield lua2python_pop(S)
        clua.lua_pop(S, 1)

    def __call__(self, *args):
        Object_pushtostack(self)
        for arg in args:
            python2lua(self._L, arg)
        check_status(self._L, clua.lua_pcall(self._L, len(args), 1, 0))
        return lua2python_pop(self._L)

    def __getattribute__(self, name):
        return self[name]

    def __setattr__(self, name, value):
        self[name] = value


def pairs(Object obj):
    # We need a new thread because we can't leave stuff on the main stack
    cdef clua.lua_State *S = clua.lua_newthread(obj._L)
    s = new_Object(obj._L)
    Object_pushtostack(obj)
    clua.lua_xmove(obj._L, S, 1)
    clua.lua_pushnil(S)
    while clua.lua_next(S, -2):
        key = lua2python(S, -2)
        val = lua2python_pop(S)
        yield key, val
    clua.lua_pop(S, 1)


def keys(Object obj):
    # We need a new thread because we can't leave stuff on the main stack
    cdef clua.lua_State *S = clua.lua_newthread(obj._L)
    s = new_Object(obj._L)
    Object_pushtostack(obj)
    clua.lua_xmove(obj._L, S, 1)
    clua.lua_pushnil(S)
    while clua.lua_next(S, -2):
        # Pop the value
        clua.lua_pop(S, 1)
        yield lua2python(S, -1)
    clua.lua_pop(S, 1)


def typename(Object obj):
    cdef int tp
    Object_pushtostack(obj)
    tp = clua.lua_type(obj._L, -1)
    clua.lua_pop(obj._L, 1)
    return clua.lua_typename(obj._L, tp)


def islist(Object obj):
    if typename(obj) != 'table':
        return False
    l = len(obj)
    for k in keys(obj):
        if not (1 <= k <= l):
            return False
    return True


def isdict(Object obj):
    return typename(obj) == 'table'


def topython(obj):
    if not isinstance(obj, Object):
        return obj
    if islist(obj):
        return map(topython, obj)
    elif isdict(obj):
        return dict((k, topython(v)) for k, v in pairs(obj))
    else:
        return obj


cdef void Object_pushtostack(Object obj):
    clua.lua_rawgeti(obj._L, clua.LUA_REGISTRYINDEX, obj._ref)


cdef object Object_compare(Object obj1, object obj2, int op):
    cdef int result
    Object_pushtostack(obj1)
    python2lua(obj1._L, obj2)
    result = clua.lua_compare(obj1._L, -2, -1, op)
    clua.lua_pop(obj1._L, 2)
    return bool(result)


cdef object Object_arith2(Object obj1, object obj2, int op):
    Object_pushtostack(obj1)
    python2lua(obj1._L, obj2)
    clua.lua_arith(obj1._L, op)
    return lua2python_pop(obj1._L)


cdef Object new_Object(clua.lua_State *L):
    cdef Object instance = Object.__new__(Object)
    instance._L = L
    instance._ref = clua.luaL_ref(L, clua.LUA_REGISTRYINDEX) 
    clua.lua_pushstring(L, "lupy_python_state")
    clua.lua_rawget(L, clua.LUA_REGISTRYINDEX)
    instance._state = <object>clua.lua_touserdata(L, -1)
    clua.lua_pop(L, 1)
    return instance


#
# Lua 'python' table functions
#

cdef int python_attrindex(clua.lua_State *L, int attrindex):
    cdef PythonData *data = check_PythonData(L, 1)
    if data == NULL:
        # TODO: throw an error
        return 0
    new_PythonData(L, <object>data.pyobj, attrindex)
    return 1


cdef int python_items(clua.lua_State *L):
    return python_attrindex(L, 0)


cdef int python_attrs(clua.lua_State *L):
    return python_attrindex(L, 1)


cdef int python_exec(clua.lua_State *L):
    cdef int nargs = clua.lua_gettop(L)
    if nargs == 0:
        return clua.luaL_error(L, "python.exec needs at least one argument")
    stmt = lua2python(L, 1)
    if not isinstance(stmt, basestring):
        return clua.luaL_error(L, "python.exec needs a string as its first argument")
    if nargs == 1:
        clua.lua_pushglobaltable(L)
    namespace = lua2python(L, 2)
    try:
        exec stmt in {}, namespace
    except Exception, e:
        python2lua(L, e)
        return clua.lua_error(L)
    return 0


cdef int python_eval(clua.lua_State *L):
    cdef int nargs = clua.lua_gettop(L)
    if nargs == 0:
        return clua.luaL_error(L, "python.eval needs at least one argument")
    expr = lua2python(L, 1)
    if not isinstance(expr, basestring):
        return clua.luaL_error(L, "python.eval needs a string as its first argument")
    if nargs == 1:
        clua.lua_pushglobaltable(L)
    namespace = lua2python(L, 2)
    try:
        result = eval(expr, {}, namespace)
    except Exception, e:
        python2lua(L, e)
        return clua.lua_error(L)
    python2lua(L, result)
    return 1


cdef void add_cfunction(clua.lua_State *L, char *name, clua.lua_CFunction fn):
    clua.lua_pushstring(L, name)
    clua.lua_pushcfunction(L, fn)
    clua.lua_rawset(L, -3)


cdef class State:
    cdef clua.lua_State *_L
    cdef object _env

    def __cinit__(self):
        cdef clua.lua_State *L = clua.luaL_newstate()
        self._L = L
        clua.luaL_openlibs(L)

        # Create the metatable for python objects
        clua.luaL_newmetatable(L, "lupy_Python")
        add_cfunction(L, "__gc", py__gc)
        add_cfunction(L, "__tostring", py__tostring)
        add_cfunction(L, "__index", py__index)
        add_cfunction(L, "__newindex", py__newindex)
        add_cfunction(L, "__call", py__call)
        add_cfunction(L, "__add", py__add)
        add_cfunction(L, "__sub", py__sub)
        add_cfunction(L, "__mul", py__mul)
        add_cfunction(L, "__div", py__div)
        add_cfunction(L, "__mod", py__mod)
        add_cfunction(L, "__pow", py__pow)
        add_cfunction(L, "__unm", py__unm)
        add_cfunction(L, "__len", py__len)
        add_cfunction(L, "__eq", py__eq)
        add_cfunction(L, "__lt", py__lt)
        add_cfunction(L, "__le", py__le)

        add_cfunction(L, "__ipairs", py__ipairs)

        clua.lua_pop(L, 1)

        # Create the python table
        clua.lua_newtable(L)
        add_cfunction(L, "items", python_items)
        add_cfunction(L, "attrs", python_attrs)
        add_cfunction(L, "exec", python_exec)
        add_cfunction(L, "eval", python_eval)
        clua.lua_setglobal(L, "python")

        # Add a reference to self in the registry index
        clua.lua_pushstring(L, "lupy_python_state")
        clua.lua_pushlightuserdata(L, <void *>self)
        clua.lua_rawset(L, clua.LUA_REGISTRYINDEX)

        # The global environment
        clua.lua_pushglobaltable(self._L)
        self._env = new_Object(self._L)

    def __dealloc__(self):
        if self._L != NULL:
            clua.lua_close(self._L)

    def run(self, char *s):
        check_status(self._L, clua.luaL_dostring(self._L, s))

    def eval(self, char *s):
        # This trick from cython user guide
        _s = "return " + s
        s = _s
        check_status(self._L, clua.luaL_loadstring(self._L, s))
        check_status(self._L, clua.lua_pcall(self._L, 0, 1, 0))
        return lua2python_pop(self._L)

    def stacksize(self):
        return clua.lua_gettop(self._L)

    def tolua(self, obj):
        python2lua_rec(self._L, obj)
        return new_Object(self._L)

    property env:

        """The global space of Lua"""

        def __get__(self):
            return self._env
