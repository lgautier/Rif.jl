===========================
Interface to the R language
===========================

R has a wealth of libraries that it would be foolish to ignore
(or try to reimplement all of them).

This packages is here to offer one to play with Julia while
calling R whenever it has a library that would be needed.

Install
=======

Requirements
------------

- R, compiled with the option --enable-R-shlib
- R executable in the ${PATH} (or path specified in the file Make.inc)

Build
-----

To build, run 'make all' from the package's directory.

For examples, check the code in examples/ .
