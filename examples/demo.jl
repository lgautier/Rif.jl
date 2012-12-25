load("Rif")

# set starting parameters for the embedded R
argv = ["Julia-R", "--slave"]# "--quiet"]
Rif.setinitargs(argv)
# initialize embedded R
Rif.initr()

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


# R's global environment
ge = Rif.getGlobalEnv()
# bind the anonymous R object in v_r to the name "foo" in the
# global environment
ge["foo"] = v_r

# get an R object, starting the search from a given environment
# (here from GlobalEnv, so like it would be from the R console)
letters = Rif.get(ge, "letters")

# use Julia's "map()"
Rif.map(letters, (x)->"letter "x)

# get the R function 'date()'
r_date = Rif.get(ge, "date")
# call it without parameters
res_date = Rif.call(r_date, [], [], ge)
res_date[0]

# get the R function 'R.Version()'
r_version = Rif.get(ge, "R.Version")
# call it without parameters
res_version = Rif.call(r_version, [], [], ge)

# get the function "toupper" (turns string to upper case)
r_toupper = Rif.get(ge, "toupper")
# call it with a blank-name parameter
res_toup = Rif.call(r_toupper, [letters,], ["",], ge)

# get the function 'mean()'
r_mean = Rif.get(ge, "mean")
v = Int32[1,2,3]
v_r = Rif.RArray{Int32, 1}(v)
# call it with a named parameter
res_mean = Rif.call(r_mean, [v_r,], ["x",], ge)

# get a loaded dataset
r_iris = Rif.get(ge, "iris")
# get names
colnames = Rif.names(r_iris)

# And now a funky macro. With it,
# just put `R` in front of the double quotes
# to evaluate the string as R code
# (the evaluation is in R's "global environment")
macro R_str(x)
    quote
        @Rif.R_str $x
    end
end

letters = R"letters"
rndvector = R"rlnorm(10)"

