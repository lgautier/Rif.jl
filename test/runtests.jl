using Base.Test
using Rif

all_tests = ["environments.jl",
             "vectors.jl",
             "functions.jl",
             "embedded_r.jl"]

# initialize embedded R
Rif.initr()

for a_test in all_tests
    println(" * $(a_test)")
    include(a_test)
end
