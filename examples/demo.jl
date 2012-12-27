require("Rif")

# initialize embedded R (with default initialization parameters)
Rif.initr()

using Rif

# R users will be familiar with the function c()
v_r = cR(1,2,3)

# It is also possible to be specify about the type
# (here a new anonymous R vector of integers)
v = Int32[1,2,3]
v_r = RArray{Int32,1}(v)
elt = v_r[1]

# new anonymous R vector of doubles
v = Float64[1.1,2.2,3.3]
v_r = RArray{Float64,1}(v)
elt = v_r[1]

# new anonymous R vector of strings
v = ["abc","def","ghi"]
v_r = RArray{ASCIIString,1}(v)
elt = v_r[1]
v_r[1]

# new anonymous R matrix of integers
v = Int32[1,2,3,4,5,6]
v_r = RArray{Int32,2}(v, 3, 2)
elt = v_r[1,1]
v_r[1,1] = int32(10)

# new anonymous R matrix of strings
v = ASCIIString["abc", "def", "ghi", "jkl", "mno", "pqr"]
v_r = RArray{ASCIIString,2}(v)
elt = v_r[1,1]

# R's global environment
ge = getGlobalEnv()
# bind the anonymous R object in v_r to the name "foo" in the
# global environment
ge["foo"] = v_r

# get an R object, starting the search from a given environment
# (here from GlobalEnv, so like it would be from the R console)
letters = get(ge, "letters")

# use Julia's "map()"
map(letters, (x)->"letter "x)

# get the R function 'date()'
r_date = get(ge, "date")
# call it without parameters
res_date = call(r_date, [], [], ge)
res_date[0]

# get the R function 'R.Version()'
r_version = get(ge, "R.Version")
# call it without parameters
res_version = call(r_version, [], [], ge)

# get the function "toupper" (turns string to upper case)
r_toupper = get(ge, "toupper")
# call it with a blank-name parameter
res_toup = call(r_toupper, [letters,], ["",], ge)

# get the function 'mean()'
r_mean = get(ge, "mean")
v = Int32[1,2,3]
v_r = RArray{Int32, 1}(v)
# call it with a named parameter
res_mean = call(r_mean, [v_r,], ["x",], ge)

# get a loaded dataset
r_iris = get(ge, "iris")
# ... or shorter
r_iris = R("iris")
# get names
colnames = names(r_iris)
# get the column called `Sepal.Length`
r_iris["Sepal.Length"]


# PCA
m = R("matrix(rnorm(100), nrow=20)")
pca = call(R("princomp"), [m])
call(R("biplot"), [pca])
