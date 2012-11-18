module Julio

using Base
#import Base.dlopen, Base.dlsym, Base.length

export initr, isinitialized, isbusy, hasinitargs, setinitargs, getinitargs,
REnvironment, RFunction,
getGlobalEnv

libri = dlopen("./src/librinterface")

function isinitialized()
    res = ccall(dlsym(libri, :EmbeddedR_isInitialized), Int32, ())
    return res
end

function hasinitargs()
    res = ccall(dlsym(libri, :EmbeddedR_hasArgsSet), Int32, ())
    return res
end

function isbusy()
    res = ccall(dlsym(libri, :EmbeddedR_isBusy), Int32, ())
    return res
end

function setinitargs(argv::Array{ASCIIString})
    argv_p = map((x)->pointer(x.data), argv)
    res = ccall(dlsym(libri, :EmbeddedR_setInitArgs), Int32,
                (Int32, Ptr{Ptr{Uint8}}), length(argv), argv_p)
    if res == -1
        if isinitialized()
            error("Initialization can no longer be performed after R was initialized.")
        else
            error("Error while trying to set the initialization parameters.")
        end
    end
end

function getinitargs()
    res = ccall(dlsym(libri, :EmbeddedR_getInitArgs), Void)
    if res == -1
        error("Error while trying to get the initialization parameters.")
    end
end

function initr()
    rhome = rstrip(readall(`R RHOME`))
    print("Using R_HOME=", rhome, "\n")
    EnvHash()["R_HOME"] = rhome
    res = ccall(dlsym(libri, :EmbeddedR_init), Int32, ())
    if res == -1
        if ! hasinitargs()
            error("Initialization parameters must be set before R can be initialized.")
        else
            error("Error while initializing R.")
        end
    end
    return res
end

abstract Sexp
#    sexp::Ptr{Void}

function named(sexp::Sexp)
    res =  ccall(dlsym(libri, :Sexp_named), Int,
                 (Ptr{Void},), sexp)
    return res
end

# FIXME: have a way to get those declarations from C ?
const NILSXP  = uint(0)
const LISTSXP = uint(2)
const CLOSXP  = uint(3)
const ENVSXP  = uint(4)
const PROMSXP  = uint(5)
const INTSXP  = uint(11)
const STRSXP  = uint(16)

function rtype(sexp::Sexp)
    res =  ccall(dlsym(libri, :Sexp_typeof), Int,
                 (Ptr{Void},), sexp.sexp)
    return res
end

function _rtype(sexp_ptr::Ptr{Void})
    res =  ccall(dlsym(libri, :Sexp_typeof), Int,
                 (Ptr{Void},), sexp_ptr)
    return res
end


## function convert(::Type{RStrVector}, x::Array{ASCIIString})
##     error("Not implemented")
## end

## function convert(::Type{Array{ASCIIString}}, x::Type{RArray{ASCIIString}})
##     error("Not implemented")
## end



## # FIXME: inherit from Julia's base Vector instead ?
## type RArray{T,N} <: Sexp
##     function RArray(x::Ptr{Void})
##         # pass
##     end
##     function RArray(x::T, y::N)
##         error("Not yet implemented.")
##     end
## end

type RArrayStr <: Sexp
    sexp::Ptr{Void}
    function RArrayStr(c_ptr::Ptr{Void})
        if _rtype(c_ptr) != STRSXP
            error("Incompatible type.")
        end
        new(c_ptr)
    end
end
    

type REnvironment <: Sexp
    sexp::Ptr{Void}
    function REnvironment()
    end

    function REnvironment(x::Ptr{Void})
        new(x)
    end

    function REnvironment(x::Sexp)
        new(x)
    end    
end

function getGlobalEnv()
    res = ccall(dlsym(libri, :EmbeddedR_getGlobalEnv), Ptr{Void},
                ())
    return REnvironment(res)
end

type RFunction <: Sexp
    sexp::Ptr{Void}
    function RFunction(x::Sexp)
    end
end

## # FIXME: a conversion would be possible ?
const _rl_dispatch = {
    3 => RFunction,
    4 => REnvironment,
    #11 => RArray{Int32}
    16 => RArrayStr }

function _factory(c_ptr::Ptr{Void})
    rtype::Int =  ccall(dlsym(libri, :Sexp_typeof), Int,
                   (Ptr{Void},), c_ptr)
    res = _rl_dispatch[rtype](c_ptr)
    return res
end

#FIXME: implement get for UTF8 symbols
function get(environment::REnvironment, symbol::ASCIIString)
    c_ptr = ccall(dlsym(libri, :Environment_get), Ptr{Void},
                 (Ptr{Void}, Ptr{Uint8}),
                environment.sexp, symbol)
    # evaluate if promise
    if _rtype(c_ptr) == PROMSXP
        c_ptr = ccall(dlsym(libri, :Sexp_evalPromise), Ptr{Void},
                      (Ptr{Void},), c_ptr)
    end
        
    return _factory(c_ptr)
end


end
