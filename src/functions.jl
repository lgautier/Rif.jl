
type RFunction <: AbstractSexp
    sexp::Ptr{Void}
    function RFunction(x::Sexp)
        new(x)
    end
    function RFunction(x::Ptr{Void})
        new(x)
    end

end

function call{T <: Sexp, U <: ASCIIString}(f::RFunction, argv::Vector{T},
                                           argn::Vector{U},
                                           env::REnvironment)
    argv_p = map((x)->x.sexp, argv)
    argn_p = map((x)->pointer(x.data), argn)
    c_ptr = ccall(dlsym(libri, :Function_call), Ptr{Void},
                  (Ptr{Void}, Ptr{Ptr{Void}}, Int32, Ptr{Uint8}, Ptr{Void}),
                  f.sexp, argv_p, length(argv), argn_p, env.sexp)
    if c_ptr == C_NULL
        println("*** Call to R function returned NULL.")
        return None
    end
    return _factory(c_ptr)
end


function call{T <: Sexp, U <: ASCIIString}(f::RFunction, argv::Vector{T},
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
function call{T <: Sexp, S <: Sexp}(f::RFunction,
                                    argkv::Dict{ASCIIString})
    call(f, [], argkv)
end

function call{T <: Sexp}(f::RFunction, argv::Vector{T})
    ge = getGlobalEnv()
    n::Integer = length(argv)
    argn = Array(ASCIIString, n)
    i::Integer = 1
    while i <= n
        argn[i] = ""
        i += 1
    end
    call(f, argv, argn, ge)
end

function call(f::RFunction)
    ge::REnvironment = getGlobalEnv()
    call(f, [], [], ge)
end

