cimport clua
cimport cpython

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
    clua.luaL_setmetatable(L, "Python")


cdef PythonData *check_PythonData(clua.lua_State *L, int index):
    """
    Return a pointer to the PythonData referred to at the given index on the
    stack, or NULL if there is none such.
    """
    return <PythonData *>clua.luaL_testudata(L, index, "Python")


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
    cdef PythonData *data
    if obj is None:
        clua.lua_pushnil(L)
    if isinstance(obj, int):
        clua.lua_pushinteger(L, obj)
    elif isinstance(obj, float):
        clua.lua_pushnumber(L, obj)
    elif isinstance(obj, basestring):
        clua.lua_pushstring(L, obj)
    elif isinstance(obj, Object):
        obj.pushtostack()
    else:
        new_PythonData(L, obj, not isinstance(obj, (list, tuple, dict)))


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

#
# Lua object wrapper for Python
#

cdef class Object:
    cdef int _ref
    cdef clua.lua_State *_L

    def __init__(self):
        raise TypeError("This class cannot be instanciated from Python")

    cdef create(self, clua.lua_State *L):
        self._L = L
        self._ref = clua.luaL_ref(L, clua.LUA_REGISTRYINDEX) 

    cdef pushtostack(self):
        clua.lua_rawgeti(self._L, clua.LUA_REGISTRYINDEX, self._ref)

    def __dealloc__(self):
        clua.luaL_unref(self._L, clua.LUA_REGISTRYINDEX, self._ref)
    
    def __repr__(self):
        return "<Lua Object %s>" % self

    def __len__(self):
        self.pushtostack()
        clua.lua_len(self._L, -1)
        return lua2python_pop(self._L)

    cdef compare(self, other, int op):
        cdef int result
        self.pushtostack()
        python2lua(self._L, other)
        result = clua.lua_compare(self._L, -2, -1, op)
        clua.lua_pop(self._L, 2)
        return bool(result)
    
    def __richcmp__(self, other, int richop):
        if richop == 0:
            return self.compare(other, clua.LUA_LT)
        elif richop == 1:
            return self.compare(other, clua.LUA_LE)
        elif richop == 2:
            return self.compare(other, clua.LUA_EQ)
        elif richop == 3:
            return not self.compare(other, clua.LUA_EQ)
        elif richop == 4:
            return not self.compare(other, clua.LUA_LE)
        elif richop == 5:
            return not self.compare(other, clua.LUA_LT)

    cdef arith2(self, other, int op):
        self.pushtostack()
        python2lua(self._L, other)
        clua.lua_arith(self._L, op)
        return lua2python_pop(self._L)

    def __add__(self, other):
        return self.arith2(other, clua.LUA_OPADD)

    def __sub__(self, other):
        return self.arith2(other, clua.LUA_OPSUB)

    def __mul__(self, other):
        return self.arith2(other, clua.LUA_OPMUL)

    def __div__(self, other):
        return self.arith2(other, clua.LUA_OPDIV)

    def __mod__(self, other):
        return self.arith2(other, clua.LUA_OPMOD)

    def __pow__(self, other, mod):
        if mod is not None:
            raise TypeError("Lua power does not support third argument")
        return self.arith2(other, clua.LUA_OPPOW)

    def __neg__(self):
        self.pushtostack()
        clua.lua_arith(self._L, clua.LUA_OPUNM)
        return lua2python_pop(self._L)

    def __str__(self):
        clua.lua_getglobal(self._L, "tostring")
        self.pushtostack()
        check_status(self._L, clua.lua_pcall(self._L, 1, 1, 0))
        return lua2python_pop(self._L)

    def __getitem__(self, key):
        self.pushtostack()
        python2lua(self._L, key)
        clua.lua_gettable(self._L, -2)
        return lua2python_pop(self._L)

    def __setitem__(self, key, val):
        self.pushtostack()
        python2lua(self._L, key)
        python2lua(self._L, val)
        clua.lua_settable(self._L, -3)
    
    def __call__(self, *args):
        self.pushtostack()
        for arg in args:
            python2lua(self._L, arg)
        check_status(self._L, clua.lua_pcall(self._L, len(args), 1, 0))
        return lua2python_pop(self._L)

    def __getattribute__(self, name):
        return self[name]

    def __setattr__(self, name, value):
        self[name] = value


cdef Object new_Object(clua.lua_State *L):
    cdef Object instance = Object.__new__(Object)
    instance.create(L)
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


cdef add_cfunction(clua.lua_State *L, char *name, clua.lua_CFunction fn):
    clua.lua_pushstring(L, name)
    clua.lua_pushcfunction(L, fn)
    clua.lua_rawset(L, -3)


cdef class State:
    cdef clua.lua_State *_L

    def __cinit__(self):
        cdef clua.lua_State *L = clua.luaL_newstate()
        self._L = L
        clua.luaL_openlibs(L)

        # Create the metatable for python objects
        clua.luaL_newmetatable(L, "Python")
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

        # Create the python table
        clua.lua_newtable(L)
        add_cfunction(L, "items", python_items)
        add_cfunction(L, "attrs", python_attrs)
        add_cfunction(L, "exec", python_exec)
        add_cfunction(L, "eval", python_eval)
        clua.lua_setglobal(L, "python")

    def __dealloc__(self):
        if self._L != NULL:
            clua.lua_close(self._L)

    cdef pushsequence(self, seq):
        cdef int i
        clua.lua_createtable(self._L, <int>len(seq), 0)
        cdef int t = clua.lua_gettop(self._L)
        for i, x in enumerate(seq, 1):
            self.python2lua(x)
            clua.lua_rawseti(self._L, t, i)

    cdef pushmap(self, map):
        clua.lua_createtable(self._L, 0, <int>len(map))
        cdef int t = clua.lua_gettop(self._L)
        for k, v in map.iteritems():
            self.python2lua(k)
            self.python2lua(v)
            clua.lua_rawset(self._L, t)

    def run(self, char *s):
        check_status(self._L, clua.luaL_dostring(self._L, s))

    def eval(self, char *s):
        # This trick from cython user guide
        _s = "return " + s
        s = _s
        check_status(self._L, clua.luaL_loadstring(self._L, s))
        check_status(self._L, clua.lua_pcall(self._L, 0, 1, 0))
        return lua2python_pop(self._L)

    property globals:

        """The global space of Lua"""

        def __get__(self):
            clua.lua_pushglobaltable(self._L)
            return new_Object(self._L)
