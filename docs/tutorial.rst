Tutorial
===============

In the following I'm assuming that you are familiar with both Python and Lua.

Creating a Lua state
--------------------

Lua's virtual machine operates on a state data structure which is explicitely passed around.  This means that a host application can start many Lua 'machines' at the same time, provided that it creates one state data structure per 'machine'.  In Lupy this is done by instanciating the ``lua.State`` class.

>>> import lua
>>> S = lua.State()

Once a state is created, you can run some lua chunks of code using its ``run()`` method.

>>> S.run('print("Hello, Python from Lua!")')
Hello, Python from Lua!

You can also evaluate Lua expressions using the ``eval()`` method of the state.  The result of the expression, which is a Lua value, is automatically translated to a Python value.  In the following example, the Lua string which is the result of evaluating the expression translated to a Python string before it is returned.

>>> S.eval('table.concat({1, 2, 3}, "::")')
'1::2::3'

Each state has a global environment (see http://www.lua.org/manual/5.2/manual.html#2.2), where global variables are (usually) resolved.  This is accessible via the ``env`` property of a lua state.

>>> S.run('x = 2')
>>> S.env.x
2

You can also set values in the global environment directly.  The Python value is then automatically translated to a Lua value - in the example below ``y`` is given the value of the Lua number 3, then ``x + y`` (a Lua number) is translated to a Python integer before being returned.

>>> S.env.y = 3
>>> S.eval('x + y')
5

Simple values
--------------------

Both Python and Lua have native datatypes to represent strings, booleans and numbers (Python makes a distinction between integers and floating point numbers for the latter).  As hinted above, values of these types in either language are automatically translated to the corresponding type when needed.

>>> S.env.z = 1 + 1 == 2
>>> S.run('print(z)')
true
>>> # Python True was translated to Lua true and printed
>>> S.eval('1 + 1 == 2')
True
>>> # Lua true was translated to Python True and printed

Working with Lua tables in Python
--------------------

Lua tables are not automatically translated to Python lists or dictionaries when needed. This is because it can be resource consuming if the table is large (all of it would need to be copied), but also because then it would not be possible to mutate the Lua table in Python code.  Instead, lua tables are wrapped in a Python class.

>>> my_table = S.eval('{45, 72, level="high"}')
>>> my_table
<Lua Object table: 0x7fb5b9616200>
>>> type(my_table)
<type 'lua.Object'>

You can find the value associated with a key in a table using either attribute or index notation, just as in Lua.

>>> my_table.level
'high'
>>> my_table['level']
'high'

The 'array' part of the table is of course 1-indexed.

>>> my_table[1]
45

You can find the length of the table using Python's ``len()`` builtin.

>>> len(my_table)
2

As in Lua, if a key does not exist in the table, no exception is thrown but ``None`` is returned.

>>> print my_table.foo
None

You can iterate over a table - it will only iterate over the 'array' part of the table, as when using lua's ``ipairs()``

>>> for x in my_table:
...     print x
... 
45
72

This means you can also turn a table into a Python list easily:

>>> list(my_table)
[45, 72]

You can use the ``lua.pairs()`` function on tables to iterate over their (key, value) pairs.

>>> for k, v in lua.pairs(my_table):
...     print k, "->", v
... 
1 -> 45
2 -> 72
level -> high

This means you can easily turn a table into a dictionary.

>>> dict(lua.pairs(my_table))
{1: 45, 2: 72, 'level': 'high'}

The function ``lua.topython()`` will translate Lua tables to either Python lists or dictionaries, depending on the keys in the table.

>>> array_table = S.eval('{4, 5, 6}')
>>> dict_table = S.eval('{ x = 12, y = 32.1, colour="blue" }')
>>> lua.topython(array_table)
[4, 5, 6]
>>> lua.topython(dict_table)
{'y': 32.1, 'x': 12, 'colour': 'blue'}

In order to add or change values to Lua tables, you can use either attribute or index notation.

>>> my_table.level = 'medium'
>>> my_table[3] = 21
>>> lua.topython(my_table)
{1: 45, 2: 72, 3: 21, 'level': 'medium'}

You can assign the value ``None`` to a key in order to remove the key from the table.

>>> my_table[3] = None
>>> lua.topython(my_table)
{1: 45, 2: 72, 'level': 'medium'}
