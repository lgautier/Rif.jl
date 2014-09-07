
type RFunction <: AbstractSexp
    sexp::Ptr{Void}
    function RFunction(x::Sexp)
        new(x)
    end
    function RFunction(x::Ptr{Void})
        new(x)
    end

end


function call(f::RFunction, args...; kwargs...)
    argv_unnamed = Any[x for x in args]
    argn_unnamed = ASCIIString["" for x in args]
    argv_named = Any[x[2] for x in kwargs]
    argn_named = ASCIIString[string(x[1]) for x in kwargs]
    rcall(f,
          vcat(argv_unnamed, argv_named),
          vcat(argn_unnamed, argn_named))
end


function rcall{U <: ASCIIString}(f::RFunction, argv::Vector,
                                 argn::Vector{U},
                                 env::REnvironment)
    argv_p = map((x)->convert(Sexp, x).sexp, argv)
    argn_p = map((x)->pointer(x.data), argn)
    c_ptr = ccall(dlsym(libri, :Function_call),
                  Ptr{Void}, # returns a pointer to an R object
                  (Ptr{Void}, # pointer to the R function
                   Ptr{Ptr{Void}}, # array of pointers to R objects as arguments
                   Int32, # number of arguments
                   Ptr{Ptr{Uint8}}, # array of names for the arguments
                   Ptr{Void}),                  
                  f.sexp, # pointer to the R function
                  argv_p, # array of pointers to R objects as arguments
                  int32(length(argv)), # number of arguments
                  argn_p, # array of names for the arguments
                  # pointer to an R environment in which the call
                  # will be evaluated)
                  env.sexp )
    if c_ptr == C_NULL
        println("*** Call to R function returned NULL.")
        return None
    end
    return _factory(c_ptr)
end


function rcall{U <: ASCIIString}(f::RFunction, argv::Vector,
                                 argn::Vector{U})
    ge::REnvironment = getGlobalEnv()
    rcall(f, argv, argn, ge)
end

##function rcall{T <: Sexp, S <: Sexp}(f::RFunction, argv::Vector{T},
##                                    argkv::Dict{ASCIIString, S})
# Precise signature currently problematic because of too loose
# inference for composite parametric types.
# ["A" => RArray, "B" => REnvironment] will be of type Dict{ASCIIString,Any}
# :/
function rcall(f::RFunction, argv::Vector,
              argkv::Dict{ASCIIString})
    ge::REnvironment = getGlobalEnv()
    n_v = length(argv)
    n_kv = length(argkv)
    n = n_v + n_kv
    c_argv = Array(Sexp, n)
    c_argn = Array(ASCIIString, n)
    i = 1
    for elt in argv
        c_argv[i] = elt
        c_argn[i] = ""
        i += 1
    end
    for (k, v) in argkv
        c_argn[i] = k
        c_argv[i] = v
        i += 1
    end
    rcall(f, c_argv, c_argn, ge)
end

##function call{T <: Sexp, S <: Sexp}(f::RFunction,
##                                    argkv::Dict{ASCIIString, S})
#function call{T <: Sexp, S <: Sexp}(f::RFunction,
function rcall(f::RFunction,
              argkv::Dict{ASCIIString})
    rcall(f, [], argkv)
end

# Types are invariant in Julia. This prevents us from
# typing the vector of arguments to something like <: AbstractSexp
# and force us to run checks explicitly :/
function rcall(f::RFunction, argv::Vector)
    ge = getGlobalEnv()
    n::Integer = length(argv)
    argn = Array(ASCIIString, n)
    i::Integer = 1
    while i <= n
        argn[i] = ""
        i += 1
    end
    rcall(f, argv, argn, ge)
end

function rcall(f::RFunction)
    ge::REnvironment = getGlobalEnv()
    rcall(f, [], [], ge)
end

