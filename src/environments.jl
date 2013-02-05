
#include("Rif/src/embeddedr.jl")
#include("Rif/src/sexp.jl")

type REnvironment <: AbstractSexp
    sexp::Ptr{Void}
    #function REnvironment()
    #end

    function REnvironment(x::Ptr{Void})
        new(x)
    end

    function REnvironment(x::Sexp)
        new(x)
    end    
end

function ref(x::REnvironment, i::ASCIIString)
    c_ptr = @librinterface_getvalue Ptr{Void} SexpEnvironment x i
    return _factory(c_ptr)
end

function assign{T <: AbstractSexp}(x::REnvironment, val::T, i::ASCIIString)
    res = @librinterface_setvalue Ptr{Void} SexpEnvironment x i val
    return res
end

function del(x::REnvironment, i::ASCIIString)
    res = ccall(dlsym(libri, :SexpEnvironment_delvalue), Int32,
                (Ptr{Void}, Ptr{Uint8}),
                x.sexp, i)
    if res == -1
        error("Element ", $i, "not found.")
    end
end

import Base.get
#FIXME: implement get for UTF8 symbols
function get(environment::REnvironment, symbol::ASCIIString)
    c_ptr = ccall(dlsym(libri, :SexpEnvironment_get), Ptr{Void},
                 (Ptr{Void}, Ptr{Uint8}),
                environment.sexp, symbol)
    # evaluate if promise
    if (@_RL_TYPEOFR(c_ptr)) == PROMSXP
        c_ptr = ccall(dlsym(libri, :Sexp_evalPromise), Ptr{Void},
                      (Ptr{Void},), c_ptr)
    end
        
    return _factory(c_ptr)
end

function getGlobalEnv()
    res = ccall(dlsym(libri, :EmbeddedR_getGlobalEnv), Ptr{Void},
                ())
    return REnvironment(res)
end

function getBaseEnv()
    res = ccall(dlsym(libri, :EmbeddedR_getBaseEnv), Ptr{Void},
                ())
    return REnvironment(res)
end
