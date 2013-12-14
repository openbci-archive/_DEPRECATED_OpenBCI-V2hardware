Requirements
------------
The easiest way to get the required libraries is to install a standard
scientific Python distribution.

This software was developed using the Anaconda Python Distribution from 
Continuum.io. It is available free for Windows, Linux and OS X:

https://store.continuum.io/cshop/anaconda/

This software should also be compatible with the PythonXY (Windows; free) 
or Enthought Python Distributions (Windows, Linux, OS X; paid).

At a minimum, you need:
  * Python 2.7
  * Numpy/Scipy
  * Enthought Tool Suite (ETS)
  * PyQt or PySide
  * matplotlib

Installation / Use
------------------

Install Python, as discussed in 'Requirements'.

Extract or check out the source code and, in that directory, call:

>> pythonw run.py

(Note that on a Mac, it is necessary to use pythonw or python.app , not bare 'python', to avoid
a window-system-related issue.

To create a binary Windows installer install cx_freeze, and then run:

>> python setup.py bdist_msi

The installer will be located in a "dist" subdirectory.

License
-------

MIT License. See LICENSE.txt.