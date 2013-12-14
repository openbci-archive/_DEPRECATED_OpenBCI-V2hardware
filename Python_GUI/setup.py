'''
setup.py
A simple cx_freeze script that is compatible with the Enthought Tool Suite.

DESCRIPTION:
This script uses the cx_freeze tool to generate an .exe of a Python script.

Internally, cx_freeze simply collects all of a program's dependencies,
compresses what it can into a library.zip file (kindof like a .jar for Python),
dumps all of the dependencies into a 'build' folder, and then bundles the
Python interpreter into a "my_program_name.exe" file. But, to the
casual observer, it looks like a normal .exe and there is no obvious
indication that it is a Python script.

The main benefit of this script vs. a random script from the internet is that
it deals properly with the Enthought Tool Suite. This is a non-trivial fix.

USAGE:
To build an exe:
    python setup.exe build_exe
To build an .msi installer:
    python setup.exe bdist_msi

PREPARATION:
To use this script, you need two files:
    *    setup.py   (this file)
    *    program_name.py  (e.g., microneb_cc.py)

program_name.py is sort of a bootstrap script that performs a few tricks
to make the frozen executable work more nicely. (see that file for details).

1)  Copy setup.py and program-name.py into your root project directory; ideally,
    your source code will be in a subdirectory named "src".
    
2)  Rename program_name.py to your actual program name; your final .exe will
    take its name from that script.
    
3)  Edit program_name.py to point to your actual program.

4)  Edit the file below any place where you see a CHANGE ME: tag.

5)  Open a command prompt in this directory, and run:
        python setup.py build_exe
        
6)  Navigate to the new 'build\exe.win32-x.x' directory, and click on
    'program-name.exe'. It should run normally.
 
'''

import sys
from cx_Freeze import setup, Executable


def GenerateBinPackageFiles():
    ''' This function makes a list of 'data files' to include with the .exe.
    These can include:
        * Images (.png, .jpg, .ico, etc) which must be carefully copied into
          the correct directory structure so that the program can find them.
        * DLL's, config files (.ini), READMEs, etc., if needed.
        * 3rd party toolkits, drivers, etc.
        
    '''

    import glob
    import os

    ############################################################################
    # Custom/Specific data files, .dlls, and other dependencies
    ############################################################################

    # CHANGE ME if you need to include other files:
    # The commented-out lines below are some random files that were needed,
    #  at one point or another, on other projects. They can provide a starting
    #  point for debugging problems.
    import numpy
    data = [
             (".", glob.glob(os.path.join(os.path.split(numpy.core.__file__)[0], '*.dll'))),
             (".", ['qdarkstyle']),
             (".", glob.glob("*.mat")),
             (".", glob.glob("*.qss")),
             ]

    ############################################################################
    # Include any images in our 'src' directory.
    ############################################################################
    myData = []
    for [dirPath, dirNames, dirFileName] in os.walk('images'):  # ' src'
        print [dirPath, dirNames, dirFileName]

        dirRoot, dirLeaf = os.path.split(dirPath)
        # Copy any 'images' directory...
        if dirLeaf.lower() == "images":
            targetDir = dirPath  # [4:]  # remove "src\"
            globPattern = os.path.join(dirPath, '*.*')
            dataFiles = glob.glob(globPattern)
            myData.append([targetDir, dataFiles])


    ############################################################################
    # Include any images in Enthought libraries.
    ############################################################################
    # These seem to be the only libraries that have 'image' subdirectories
    # that cause bugs if they're left out.
    import pyface
    import traitsui.qt4
    import pyface.ui.qt4
    import enable

    # Find the actual location on disk of those packages.
    traitsUI_dir = os.path.split(traitsui.__file__)[0]
    pyface_dir = os.path.split(pyface.__file__)[0]
    qtBackendPyface_dir = os.path.split(pyface.ui.qt4.__file__)[0]
    qtBackendTraits_dir = os.path.split(traitsui.qt4.__file__)[0]
    enable_dir = os.path.split(enable.__file__)[0]

    # Search those directories for any images directories, and include them.
    etsData = [('pyface/images', glob.glob(os.path.join(pyface_dir, 'images', '*'))),
               ('enable', glob.glob(os.path.join(enable_dir, 'images.zip'))),
               ('pyface/ui/qt4/images', glob.glob(os.path.join(qtBackendPyface_dir, 'images', '*'))),
               ('traitsui/qt4/images', glob.glob(os.path.join(qtBackendTraits_dir, 'images', '*'))),
               ('traitsui/image/library', glob.glob(os.path.join(traitsUI_dir, 'image', 'library', '*')))]


    ############################################################################
    # Assemble our files into a CX_FREEZE compatible list.
    ############################################################################
    for entry in myData:
        data.append(entry)

    for entry in etsData:
        data.append(entry)

    # Remove SVN directories.
    data = [ [a, b] for [a, b] in data if a.find('.svn') < 0 ]

    # Transform to format the cx_freeze uses, as opposed to the old py2exe format.
    #  (old format is list of [dest_dir, list_of_files],
    #   new format is list of [src_file, dest_file])
    src_dst_tuples = []
    for dst_dir, file_list in data:
        for src in file_list:
            src_dir, src_file = os.path.split(src)
            dst = os.path.join(dst_dir, src_file)
            src_dst_tuples.append((src, dst))

    return src_dst_tuples


################################################################################
# Packages to EXCLUDE
################################################################################
# CHANGE ME: If you need any of these libraries; we exclude them to save space
#            and prevent conflicts.
excludes = [
            # These cause errors and can't be included. ########################
            # ...
            # These we exclude just to save space/time #########################
            'Tkinter',
            ]

################################################################################
# Packages to INCLUDE
################################################################################
# CHANGE ME: If you run your program and get an error message than a library
#            is missing. (Sometimes, cx_freeze isn't able to automatically find
#            all dependencies.)

includes = ['matplotlib',
            'atexit',
            'pyface',
            'pyface.ui',
            'pyface.ui.qt4', 'pyface.ui.qt4.action', 'pyface.ui.qt4.tasks',
            'pyface.ui.qt4.timer', 'pyface.ui.qt4.wizard',
            'pyface.ui.qt4.workbench',
            'pyface.qt',  # a
            'pyface',
            'enable.qt4',
            'numpy',

            # The following are unexpected dependencies. If you are concerned about
            # space, try removing them.
            'scipy.special._ufuncs',
            'scipy.signal.bsplines',
            'scipy.sparse.csgraph._validation',
            'numpy.core',
            'scipy.sparse.linalg.dsolve.umfpack',
            'scipy.integrate',
            'scipy.io.matlab.streams',

            ]


################################################################################
# Put it all together....
################################################################################
# CHANGE ME: If you don't have an icon in the path defined below, or if
#            your files are not all in the 'src' subdirectory.
build_exe_options = {"packages": includes,
                     "excludes": excludes,
                     "include_files": GenerateBinPackageFiles(),
                     "icon": "images/application.ico",
                     "path": sys.path + [".", ],  # ["src", ]
                     "include_msvcr": True,
                     }

bdist_msi_options = {
     # upgrade_code a GUID that lets us uninstall previous versions.
     # If you are adapting this script to a new app, you need to
     # change this code so that you don't accidentally uninstall
     # something!
    "upgrade_code": "{95b85bac-52af-4009-9e94-3afcc9e0ad0c}"
    }

# GUI applications require a different base on Windows (the default is for a
# console application).
base = None
if sys.platform == "win32":
    base = "Win32GUI"

# CHANGE ME: Here you can define the name, version, etc. of your program.
#        Make sure that the correct .py file is referenced here... you want
#        to reference program_name.py (e.g., microneb_cc.py).
setup(name="EEG Sensor Console",
        version="0.4.0",
        description="EEG Sensor Console",
        options={"build_exe": build_exe_options,
                 "bdist_msi": bdist_msi_options},
        executables=[Executable("run.py",
                                base=base,
                                shortcutName="EEG Sensor Console",
                                shortcutDir='ProgramMenuFolder')])



