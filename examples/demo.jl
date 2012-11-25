include("lib/Julio.jl")
#using Julio

#

argv = ["Julio", "--slave"]# "--quiet"]
Julio.setinitargs(argv)
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

# get an R object, starting the search from a given environment
# (here from GlobalEnv, so like it would be from the R console)
lt = Julio.get(ge, "letters")

# get the function 'date()'
r_date = Julio.get(ge, "date")
# call it without parameter
res_date = Julio.call(r_date, [], [], ge)

# get the function 'mean()'
r_mean = Julio.get(ge, "mean")
v = Int32[1,2,3]
v_r = Julio.RArrayInt32(v)
# call it with a parameter
res_mean = Julio.call(r_mean, [v_r,], ["x",], ge)


r_toupper = Julio.get(ge, "toupper")
res_toup = Julio.call(r_toupper, [lt,], ["",], ge)

r_seq = Julio.get(ge, "seq")
res_seq = Julio.call(r_seq, [], [], ge)


#libri = Julio.libri
#argv_p = map((x)->pointer(x.data), argv)
#res = ccall(dlsym(libri, :EmbeddedR_setInitArgs), Int,
#            (Int32, Ptr{Ptr{Uint8}}), length(argv), argv_p)

#rhome = rstrip(readall(`R RHOME`))
#EnvHash()["R_HOME"] = rhome
#Julio.initr()

#ccall(dlsym(libri, :EmbeddedR_isInitialized), Int32, ())

#sexp = ccall(dlsym(libri, :EmbeddedR_getGlobalEnv), Ptr{Void}, ())
