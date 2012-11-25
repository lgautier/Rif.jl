include("lib/Julio.jl")
#using Julio

# set starting parameters for the embedded R
argv = ["Julio", "--slave"]# "--quiet"]
Julio.setinitargs(argv)
# initialize embedded R
Julio.initr()

# new anonymous R vector of integers
v = Int32[1,2,3]
v_r = Julio.RArrayInt32(v)
elt = v_r[int32(1)]

# new anonymous R vector of doubles
v = Float64[1.0,2.0,3.0]
v_r = Julio.RArrayFloat64(v)
elt = v_r[int32(1)]

# new anonymous R vector of strings
v = ["abc","def","ghi"]
v_r = Julio.RArrayStr(v)
elt = v_r[int32(1)]


# R's global environment
ge = Julio.getGlobalEnv()
# bind the anonymous R object in v_r to the name "foo" in the
# global environment
ge["foo"] = v_r

# get an R object, starting the search from a given environment
# (here from GlobalEnv, so like it would be from the R console)
lt = Julio.get(ge, "letters")

# use Julia's "map()"
Julio.map(lt, (x)->"letter "x)

# get the R function 'date()'
r_date = Julio.get(ge, "date")
# call it without parameters
res_date = Julio.call(r_date, [], [], ge)

# get the R function 'R.Version()'
r_version = Julio.get(ge, "R.Version")
# call it without parameters
res_version = Julio.call(r_version, [], [], ge)

# get the function "toupper" (turns string to upper case)
r_toupper = Julio.get(ge, "toupper")
# call it with a blank-name parameter
res_toup = Julio.call(r_toupper, [lt,], ["",], ge)

# get the function 'mean()'
r_mean = Julio.get(ge, "mean")
v = Int32[1,2,3]
v_r = Julio.RArrayInt32(v)
# call it with a named parameter
res_mean = Julio.call(r_mean, [v_r,], ["x",], ge)

# get a loaded dataset
r_iris = Julio.get(ge, "iris")
# get names
Julio.names(r_iris)[1]
