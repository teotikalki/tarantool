# tarantool [![Build Status](https://travis-ci.org/tarantool/tarantool.png?branch=master)](https://travis-ci.org/tarantool/tarantool)

http://tarantool.org 

Tarantool is an efficient in-memory NoSQL database and a
Lua application server, blended.

Key features of the system:
 * flexible data model
 * multiple index types: HASH, TREE, BITSET
 * optional persistence and strong data durability
 * log streaming replication
 * lua functions, procedures, triggers, with
   rich access to database API, JSON support,
   inter-procedure and network communication libraries

Tarantool is ideal for data-enriched components of 
scalable Web architecture: traditional database caches, queue
servers, in-memory data store for hot data, and so on.

Supported platforms are Linux/x86 and FreeBSD/x86, Mac OS X.

## Compilation and install

Tarantool is written in C and C++.
To build, you will need GCC or Apple CLang compiler.

CMake is used for configuration management.
3 standard CMake build types are supported:
 * Debug -- used by project maintainers
 * RelWithDebugInfo -- the most common release configuration,
 also provides debugging capabilities
 * Release -- use only if the highest performance is required

The only external library dependency is readline: libreadline-dev.

There are two OPTIONAL dependencies: 
- uuid-dev. It is required for box.uuid_* functions.
- GNU bfd (part of GNU binutils). It's used to print 
a stack trace after a crash.

Please follow these steps to compile Tarantool:

    # If compiling from git
    tarantool $ git submodule init
    tarantool $ git submodule update

    tarantool $ cmake .
    tarantool $ make

To use a different release type, say, RelWithDebugInfo, use:

    tarantool $ cmake . -DCMAKE_BUILD_TYPE=RelWithDebugInfo

Additional build options can be set similarly:

    tarantool $ cmake . -DCMAKE_BUILD_TYPE=RelWithDebugInfo -DENABLE_DOC=true # builds the docs

'make' creates tarantool executable in directory src/.

There is no 'make install' goal, but no installation
is required either.
Tarantool regression testing framework (test/test-run.py) is the
simplest way to setup and start the server, but it requires a few
additional Python modules:
 * daemon
 * pyyaml

Once all prerequisites are installed, try:

    tarantool $ cd test
    tarantool $ ./test-run.py --suite box --start-and-exit

This will create a 'var' subdirectory in directory 'test',
populate it with necessary files, and
start the server. To connect, start the server in interactive
mode:

    tarantool $ ./src/tarantool

Alternatively, if a customized server configuration is required,
you could follow these steps:

    tarantool $ emacs cfg/tarantool.cfg # edit the configuration
    # Initialize the storage directory, path to this directory
    # is specified in the configuration file:
    tarantool $ src/box/tarantool_box --config cfg/tarantool.cfg --init-storage
    # Run tarantool
    tarantool $ src/box/tarantool_box --config cfg/tarantool.cfg

Please report bugs at http://github.com/tarantool/tarantool/issues
We also warmly welcome your feedback in the discussion mailing
list, tarantool@googlegroups.com.

Thank you for your interest in Tarantool!
