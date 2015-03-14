Lupy ("loopy") provides Python module that creates a two-way bridge between Python and Lua.  It's written in Cython, which makes is very short.

To build lupy, just do:
```
cd lupy
python setup.py build_ext -i
```

This will create a `lua` Python module:
```
$ python
Python 2.7.2 [...]
Type "help", "copyright", "credits" or "license" for more information.
>>> import lua
>>> s = lua.State()
>>> s.run("print('Hello, ' .. 'World!')")
Hello, World!
>>> s.eval("40 + 2")
42
>>> s.eval("1 + 1 ~= 2")
False
>>> s.run("x = table.concat({1, 2, 3}, ':')")
>>> s.globals.x
'1:2:3'
>>> s.globals.y = "You can set globals from python too"
>>> s.run('print(y)')
You can set globals from python too
>>> s.env.z = {'a': 'python', 'object':'in Lua!'}
>>> s.eval("z.a")
'python'
>>> s.run('python.eval(table.concat({1, 2, 3}, "+"))')
>>> s.eval('3/python.eval(table.concat({1, 2, 3}, "+"))')
0.5
```

Dependencies are:

  * [Python](http://python.org) (I use 2.7, but I guess 2.5+ works, 3.x may work).
  * [Cython](http://cython.org) (I use 0.17.4, probably earlier versions will work as well). You can probably install it with `easy_install cython` or `pip install cython`.
  * [Lua 5.2](http://www.lua.org).  Note that it will not work with earlier versions of Lua as there are incompatibilities between the C API of Lua 5.2 and of Lua 5.1.