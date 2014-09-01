
type RFunction <: AbstractSexp
    sexp::Ptr{Void}
    function RFunction(x::Sexp)
        new(x)
    end
    function RFunction(x::Ptr{Void})
        new(x)
    end

end

function call{U <: ASCIIString}(f::RFunction, argv::Vector,
                                argn::Vector{U},
                                env::REnvironment)
    argv_p = map((x)->x.sexp, argv)
    argn_p = map((x)->pointer(x.data), argn)
    c_ptr = ccall(dlsym(libri, :Function_call),
                  Ptr{Void}, # returns a pointer to an R object
                  (Ptr{Void}, Ptr{Ptr{Void}}, Int32, Ptr{Ptr{Uint8}}, Ptr{Void}),
                  # pointer to the R function
                  f.sexp,
                  # array of pointers to R objects as arguments
                  argv_p,
                  # number of arguments (length of the arrays above and below)
                  int32(length(argv)),
                  # array of names for the arguments
                  argn_p,
                  # pointer to an R environment in which the call
                  # will be evaluated)
                  env.sexp )
    if c_ptr == C_NULL
        println("*** Call to R function returned NULL.")
        return None
    end
    return _factory(c_ptr)
end


function call{U <: ASCIIString}(f::RFunction, argv::Vector,
                                argn::Vector{U})
    ge::REnvironment = getGlobalEnv()
    call(f, argv, argn, ge)
end

##function call{T <: Sexp, S <: Sexp}(f::RFunction, argv::Vector{T},
##                                    argkv::Dict{ASCIIString, S})
# Precise signature currently problematic because of too loose
# inference for composite parametric types.
# ["A" => RArray, "B" => REnvironment] will be of type Dict{ASCIIString,Any}
# :/
function call(f::RFunction, argv::Vector,
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
    call(f, c_argv, c_argn, ge)
end

##function call{T <: Sexp, S <: Sexp}(f::RFunction,
##                                    argkv::Dict{ASCIIString, S})
#function call{T <: Sexp, S <: Sexp}(f::RFunction,
function call(f::RFunction,
              argkv::Dict{ASCIIString})
    call(f, [], argkv)
end

# Types are invariant in Julia. This prevents us from
# typing the vector of arguments to something like <: AbstractSexp
# and force us to run checks explicitly :/
function call(f::RFunction, argv::Vector)
    ge = getGlobalEnv()
    n::Integer = length(argv)
    argn = Array(ASCIIString, n)
    i::Integer = 1
    while i <= n
        if ! (typeof(argv[i]) <: AbstractSexp)
            error("Argument $(i) should be a subtype of AbstractSexp")
        end
        argn[i] = ""
        i += 1
    end
    call(f, argv, argn, ge)
end

function call(f::RFunction)
    ge::REnvironment = getGlobalEnv()
    call(f, [], [], ge)
end

