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

Rif.initr()
```

If needed, the initialization parameters can be specified:
```
# set initialization parameters for the embedded R
argv = ["Julia-R", "--slave"]
# set the parameters
Rif.setinitargs(argv)
# initialize embedded R
Rif.initr()
```

Vectors and arrays
------------------

### Vectors

In R there are no scalars, only vectors.

```
# Use R's c()
v = Rif.cR(1,2,3)

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

### Matrices and Arrays

Matrices are arrays of dimension 2:
```
v = Int32[1,2,3,4,5,6]
v_r = Rif.RArray{Int32,2}(v)
elt = v_r[1,1]
v_r[1,1] = int32(10)

```

Environments
------------

In R variables are defined in environments and calls are evaluated
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

# other way to achieve the same:
res_mean = Rif.call(r_mean, [], ["x" => v_r])

```

R code in strings
-----------------


```
using Rif

# load the R package "cluster"
R("require(cluster)")

# today's date by calling R's date()
call(R("date"))[1]

```


Examples
========

Not-so-simple example, using some of the documentation for `autoplot()` in the Bioconductor package `ggbio`.

```
require("Rif")
using Rif
initr()

```

```
R("set.seed(1)")
N = 1000
requireR("GenomicRanges")
function sampleR(robj, size, replace)
call(R("sample"), [robj], Rp(["size" => cR(size), "replace" => cR(replace)]))
end

gr = call(R("GRanges"), [],
          ["seqnames" => sampleR(cR("chr1", "chr2", "chr3"), N, true),
           "ranges" => call(R("IRanges"), [],
                            Rp(["start" => sampleR(R("1:300"), N, true),
                                "width" => sampleR(R("70:75"), N, true)])),
           "strand" => sampleR(cR("+", "-", "*"), N, true),
           "value" => call(R("rnorm"), [cR(N), cR(10), cR(3)]),
           "score" => call(R("rnorm"), [cR(N), cR(100), cR(30)]),
           "sample" => sampleR(cR("Normal", "Tumor"), N, true), 
           "pair" => sampleR(R("letters"), N, true)])
```

For reference, the original R code:
```
set.seed(1)
N <- 1000
library(GenomicRanges)
gr <- GRanges(seqnames = 
              sample(c("chr1", "chr2", "chr3"),
                       size = N, replace = TRUE),
              IRanges(
                      start = sample(1:300, size = N, replace = TRUE),
                      width = sample(70:75, size = N,replace = TRUE)),
              strand = sample(c("+", "-", "*"), size = N, 
                              replace = TRUE),
              value = rnorm(N, 10, 3), score = rnorm(N, 100, 30),
              sample = sample(c("Normal", "Tumor"), 
              size = N, replace = TRUE),
              pair = sample(letters, size = N, 
              replace = TRUE))
```


```
requireR("ggbio")
gr = call(R("seqlength<-"), [gr, RArray{Int32, 1}(Int32[400, 500, 700])])

```
...hmmm... crash with stack smashing detected at this point....

R code:
```
require(ggbio)
seqlengths(gr) <- c(400, 500, 700)
values(gr)$to.gr <- gr[sample(1:length(gr), size = length(gr))]
idx <- sample(1:length(gr), size = 50)
gr <- gr[idx]
ggplot() + 
  layout_circle(gr, geom = "ideo", fill = "gray70", 
                radius = 7, trackWidth = 3) +
  layout_circle(gr, geom = "bar", radius = 10, trackWidth = 4, 
                aes(fill = score, y = score)) +
  layout_circle(gr, geom = "point", color = "red", radius = 14,
                trackWidth = 3, grid = TRUE, aes(y = score)) +
  layout_circle(gr, geom = "link", linked.to = "to.gr", 
                radius = 6, trackWidth = 1)

```     