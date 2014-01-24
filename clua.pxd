from libc.stddef cimport ptrdiff_t


cdef extern from *:
    ctypedef char* const_char_ptr "const char*"


cdef extern from "lua.h":
    ctypedef struct lua_State:
        pass
    ctypedef ptrdiff_t lua_Integer
    ctypedef double lua_Number
    ctypedef int (*lua_CFunction) (lua_State *L)

    cdef int LUA_TNONE "LUA_TNONE"

    cdef int LUA_TNIL "LUA_TNIL"
    cdef int LUA_TBOOLEAN "LUA_TBOOLEAN"
    cdef int LUA_TLIGHTUSERDATA "LUA_TLIGHTUSERDATA"
    cdef int LUA_TNUMBER "LUA_TNUMBER"
    cdef int LUA_TSTRING "LUA_TSTRING"
    cdef int LUA_TTABLE "LUA_TTABLE"
    cdef int LUA_TFUNCTION "LUA_TFUNCTION"
    cdef int LUA_TUSERDATA "LUA_TUSERDATA"
    cdef int LUA_TTHREAD "LUA_TTHREAD"

    cdef int LUA_NUMTAGS "LUA_NUMTAGS"

    cdef int LUA_REGISTRYINDEX "LUA_REGISTRYINDEX"

    cdef int LUA_RIDX_MAINTHREAD "LUA_RIDX_MAINTHREAD"
    cdef int LUA_RIDX_GLOBALS "LUA_RIDX_GLOBALS"
    cdef int LUA_RIDX_LAST "LUA_RIDX_LAST"

    cdef int LUA_OK "LUA_OK"
    cdef int LUA_YIELD "LUA_YIELD"
    cdef int LUA_ERRRUN "LUA_ERRRUN"
    cdef int LUA_ERRSYNTAX "LUA_ERRSYNTAX"
    cdef int LUA_ERRMEM "LUA_ERRMEM"
    cdef int LUA_ERRGCMM "LUA_ERRGCMM"
    cdef int LUA_ERRERR "LUA_ERRERR"

    cdef int LUA_OPADD "LUA_OPADD"
    cdef int LUA_OPSUB "LUA_OPSUB"
    cdef int LUA_OPMUL "LUA_OPMUL"
    cdef int LUA_OPDIV "LUA_OPDIV"
    cdef int LUA_OPMOD "LUA_OPMOD"
    cdef int LUA_OPPOW "LUA_OPPOW"
    cdef int LUA_OPUNM "LUA_OPUNM"

    cdef int LUA_OPEQ "LUA_OPEQ"
    cdef int LUA_OPLT "LUA_OPLT"
    cdef int LUA_OPLE "LUA_OPLE"

    void lua_close(lua_State *L)

    int lua_gettop (lua_State *L)
    void lua_pop(lua_State *L, int n)
    void lua_pushboolean(lua_State *L, int b)
    void lua_pushinteger (lua_State *L, lua_Integer n)
    const_char_ptr lua_pushstring (lua_State *L, const_char_ptr s)
    void lua_pushnumber (lua_State *L, lua_Number n)
    void lua_pushvalue (lua_State *L, int index)
    void lua_pushnil (lua_State *L)
    void lua_pushlightuserdata (lua_State *L, void *p)

    void lua_setglobal (lua_State *L, const_char_ptr name)
    void lua_getglobal (lua_State *L, const_char_ptr name)
    void lua_pushglobaltable(lua_State *L)

    int lua_type (lua_State *L, int index)
    const_char_ptr lua_typename (lua_State *L, int tp)

    lua_Number lua_tonumber (lua_State *L, int index)
    const_char_ptr lua_tostring (lua_State *L, int index)
    int lua_toboolean (lua_State *L, int index)

    void *lua_newuserdata (lua_State *L, size_t size)
    void *lua_touserdata (lua_State *L, int index)

    void lua_newtable (lua_State *L)
    void lua_createtable (lua_State *L, int narr, int nrec)
    void lua_gettable (lua_State *L, int index)
    void lua_settable (lua_State *L, int index)
    void lua_rawgeti (lua_State *L, int index, int n)
    void lua_rawseti (lua_State *L, int index, int n)
    void lua_rawget (lua_State *L, int index)
    void lua_rawset (lua_State *L, int index)
    
    void lua_len (lua_State *L, int index)
    int lua_next (lua_State *L, int index)

    int lua_pcall (lua_State *L, int nargs, int nresults, int msgh)
    void lua_pushcfunction (lua_State *L, lua_CFunction f)

    int lua_compare (lua_State *L, int index1, int index2, int op)
    void lua_concat (lua_State *L, int n)
    void lua_arith (lua_State *L, int op)

    int lua_error (lua_State *L)

    lua_State *lua_newthread (lua_State *L)
    int lua_resume (lua_State *L, lua_State *from_, int nargs)
    int lua_yieldk (lua_State *L, int nresults, int ctx, lua_CFunction k)
    void lua_xmove (lua_State *from_, lua_State *to, int n)


cdef extern from "lauxlib.h":

    cdef int LUA_NOREF "LUA_NOREF"
    cdef int LUA_REFNIL "LUA_REFNIL"
    
    lua_State *luaL_newstate()
    int luaL_dostring (lua_State *L, const_char_ptr str)
    int luaL_ref (lua_State *L, int t)
    void luaL_unref (lua_State *L, int t, int ref)
    int luaL_loadstring (lua_State *L, const_char_ptr s)
    int luaL_newmetatable (lua_State *L, const_char_ptr tname)
    void luaL_setmetatable (lua_State *L, const_char_ptr tname)
    void luaL_getmetatable (lua_State *L, const_char_ptr tname)
    void *luaL_testudata (lua_State *L, int arg, const_char_ptr tname)
    int luaL_error (lua_State *L, const_char_ptr fmt, ...)


cdef extern from "lualib.h":

    void luaL_openlibs (lua_State *L)


