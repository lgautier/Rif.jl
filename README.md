===========================
Interface to the R language
===========================

R has a wealth of libraries that it would be foolish to ignore
(or try to reimplement all of them).

This packages is here to offer one to play with Julia while
calling R whenever it has a library that would be needed.

Installation
============

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


Usage
=====

Initialization
--------------

The package is using an embedded R, which needs to be initalized
before anything useful can be done.

```
require("Rif")

# set initialization parameters for the embedded R
argv = ["Julia-R", "--slave"]
# set the parameters
Rif.setinitargs(argv)
# initialize embedded R
Rif.initr()
```

Vectors and arrays
------------------

Vectors
^^^^^^^

In R there are no scalars, only vectors.

```
# new anonymous R vector of integers
v = Int32[1,2,3]
v_r = Rif.RArray{Int32,1}(v)
elt = v_r[1]

# new anonymous R vector of doubles
v = Float64[1.0,2.0,3.0]
v_r = Rif.RArray{Float64,1}(v)
elt = v_r[1]

# new anonymous R vector of strings
v = ["abc","def","ghi"]
v_r = Rif.RArray{ASCIIString,1}(v)
elt = v_r[1]
```

Matrices and Arrays
^^^^^^^^^^^^^^^^^^^

Matrices are arrays of dimension 2:
```
v = Int32[1,2,3,4,5,6]
v_r = Rif.RArray{Int32,2}(v)
elt = v_r[1,1]
v_r[1,1] = int32(10)

```

Environments
------------

In R, variables are defined in environments, and call are evaluated
in environments as well. One can think of them as namespaces.
When running R interactively, one is normally in the "Global Environment"
(things are only different when in the debugger).

```
# R's global environment
ge = Rif.getGlobalEnv()
# bind the anonymous R object in v_r to the name "foo" in the
# global environment
ge["foo"] = v_r
```

```
# get an R object, starting the search from a given environment
# (here from GlobalEnv, so like it would be from the R console)
letters = Rif.get(ge, "letters")
```


Functions
---------

```
# get the R function 'date()'
r_date = Rif.get(ge, "date")
# call it without parameters
res_date = Rif.call(r_date, [], [], ge)
res_date[0]
```

```
# get the function 'mean()'
r_mean = Rif.get(ge, "mean")
v = Int32[1,2,3]
v_r = Rif.RArray{Int32, 1}(v)
# call it with a named parameter
res_mean = Rif.call(r_mean, [v_r,], ["x",], ge)
```

R code in strings
-----------------


```
using Rif

# load the R package "cluster"
R"require(cluster)"

# today's date by calling R's date()
call(R"date")[1]

```