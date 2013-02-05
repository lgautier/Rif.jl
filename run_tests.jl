require("test.jl")

using Rif

all_tests = ["test/environments.jl",
             "test/functions.jl"]

println("Running tests:")

# initialize embedded R
Rif.initr()

for a_test in all_tests
    println(" * $(a_test)")
    include(a_test)
end
