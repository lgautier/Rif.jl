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

Build and install
-----------------

This is a valid Julia package. Once you have all the METADATA.jl jazz for Julia packages sorted out
(exercise left to the reader), installing a building will be done with:
```
julia> require("pkg")
julia> Pkg.add("Rif")
```
Once this is done, in a subsequent Julia process one can just write 
```
julia> require("Rif")
```
The first time it is done, the C part of the package will be compiled against the R
found in the `$PATH`.


