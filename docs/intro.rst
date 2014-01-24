Introduction
=================

Lupy is a Python-Lua bridge that takes the form of a Python module.  It allows the creation of any number of Lua states from within Python and makes it easy for both environments to interact.  The Lua states and the Python process can introspect each other's data structures easily and can also execute code in the other language or call functions / methods.


Why Lupy?
---------------------

Lua is a scripting language with a very small footprint which can easily be embedded in a C or C++ application.  It doesn't have much of a standard library but this is not usually a problem because the host application will provide it with an API to do what it needs to do

Python is also a scripting language.  It can be used very effectively to create prototype quickly.  Using Lupy, you can create APIs for Lua in only a few lines of code.  This means you can e.g. prototype the host application very quickly or mock it for the purpose of testing the Lua code.


Quick example: a regex engine for Lua
----------------------------------------

This example shows how Python's ``re`` module can be made accessible to Lua and simply used from within Lua. 

>>> import lua
>>> import re
>>> # Here we create a Lua state
>>> S = lua.State()
>>> # Here we make the re module available to Lua as a global object
>>> S.env.re = re
>>> # The code below is Lua code making direct use of the Python re module
>>> S.run("""
... m = re.search('([a-zA-Z.]+)@([a-z.])+', 'Please email bob@gmail.com')
... if m then
...     local username = m.groups()[0]
...     print(username, 'has length', username:len())
... end
... """)
bob	has length	3


Quick example: using Lua functions in Python
-----------------------------------------

This example shows how a Lua library (the builtin string library) can be used directly in Python.

>>> import lua
>>> S = lua.State()
>>> string = S.env.string
>>> string.reverse('lupy')
'ypul'
>>> # Using Lua pattern matching in Python
>>> string.gsub("hello world from Lua", "(%w+)%s*(%w+)", "%2 %1")
'world hello Lua from'


Building Lupy
---------------------

Lupy requires Python (http://www.python.org/).  I have built it against Python 2.7 only but it may work for 2.6 or even 2.5.  It may also work for Python 3.x?

Lupy is implemented using Cython (http://http://cython.org/).  Cython 0.17 or later should work.  Earlier versions may work.

It requires Lua 5.2 (http://www.lua.org/download.html) and will not work with Lua 5.1 or earlier as a few parts of the Lua API have made some backward-incompatible changes in 5.2 (it wouldn't be too difficult to make it work for 5.1 but it is not something I have needed so far)

In order to build Lupy, just do::

    $ cd /path/to/lupy
    $ python setup.py build_ext -i

This will create a ``lua`` module.  To check that it worked, try from an interactive Python session:

>>> import lua
>>> s = lua.State()
>>> s.run("print('Hello, ' .. 'Lua!')")
Hello, Lua!

The module can be installed like this::

    $ sudo python setup.py install



