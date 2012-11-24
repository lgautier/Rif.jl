module Julio

using Base
#import Base.dlopen, Base.dlsym, Base.length
import Base.assign, Base.ref, Base.convert, Base.length

export initr, isinitialized, isbusy, hasinitargs, setinitargs, getinitargs,
       REnvironment, RFunction,
       RArrayInt32, RArrayFloat64, RArrayStr,
       ref, assign,
       getGlobalEnv

libri = dlopen("./deps/librinterface")

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

abstract SexpArray <: Sexp

function length{T <: SexpArray}(sexp::T)
    res =  ccall(dlsym(libri, :Sexp_length), Int,
                 (Ptr{Void},), sexp)
    return res
end
    
# FIXME: have a way to get those declarations from C ?
const NILSXP  = uint(0)
const SYMSXP  = uint(1)
const LISTSXP = uint(2)
const CLOSXP  = uint(3)
const ENVSXP  = uint(4)
const PROMSXP  = uint(5)
const BUILTINSXP  = uint(8)
const LGLSXP  = uint(10)
const INTSXP  = uint(11)
const STRSXP  = uint(16)
const S4SXP  = uint(25)

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


function convert{T <: Sexp}(::Type{Ptr{Void}}, x::T)
    x.sexp
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

type RArrayInt32 <: SexpArray
    sexp::Ptr{Void}
    function RArrayInt32(c_ptr::Ptr{Void})
        if _rtype(c_ptr) != INTSXP
            error("Incompatible type.")
        end
        new(c_ptr)
    end
    function RArrayInt32(v::Vector{Int32})
        c_ptr = ccall(dlsym(libri, :SexpIntVector_new), Ptr{Void},
                      (Ptr{Int32}, Int32),
                      v, length(v))
        new(c_ptr)
    end
end    


macro librinterface_getitem(returntype, classname, x, i)
    local f = "$(classname)_getitem"
    quote
       local res = ccall(dlsym(libri, $f), $returntype,
                         (Ptr{Void}, Int32),
                         $x.sexp, $i)
       if res == C_NULL
           error("Error while getting element ", $i, ".")
       end
       res
    end
end

macro librinterface_setitem(valuetype, classname, x, i, value)
    local f = "$(classname)_setitem"
    quote
       local res = ccall(dlsym(libri, $f), Int32,
                         (Ptr{Void}, Int32, $valuetype),
                         $x.sexp, $i, $value)
       if res == -1
           error("Error while setting element ", $i, ".")
       end
       res
    end
end

function ref(x::RArrayInt32, i::Int32)
    res = @librinterface_getitem Int32 SexpIntVector x i
    return res
end

#function convert
#    c_ptr = ccall(dlsym(libri, :SexpIntVector_ptr), Ptr{Int32},
#                  (Ptr{Void},),
#                  res.sexp)

function assign(x::RArrayInt32, val::Int32, i::Int32)
    res = @librinterface_setitem Int32 SexpIntVector x i val
    return res
end

type RArrayFloat64 <: SexpArray
    sexp::Ptr{Void}
    function RArrayFloat64(c_ptr::Ptr{Void})
        if _rtype(c_ptr) != REALSXP
            error("Incompatible type.")
        end
        new(c_ptr)
    end
    function RArrayFloat64(v::Vector{Float64})
        c_ptr = ccall(dlsym(libri, :SexpDoubleVector_new), Ptr{Void},
                      (Ptr{Float64}, Int32),
                      v, length(v))
        new(c_ptr)
    end
end    

function ref(x::RArrayFloat64, i::Int32)
    res = @librinterface_getitem Float64 SexpDoubleVector x i
    return res
end

function assign(x::RArrayFloat64, val::Float64, i::Int32)
    res = @librinterface_setitem Float64 SexpIntVector x i val
    return res
end


type RArrayStr <: SexpArray
    sexp::Ptr{Void}
    function RArrayStr(c_ptr::Ptr{Void})
        if _rtype(c_ptr) != STRSXP
            error("Incompatible type.")
        end
        new(c_ptr)
    end
    function RArrayStr(v::Vector{ASCIIString})
        c_ptr = ccall(dlsym(libri, :SexpStrVector_new), Ptr{Void},
                      (Ptr{Uint8}, Int32),
                      v, length(v))
        new(c_ptr)
    end

end

## function convert(::Array{ASCIIString}, x::RArrayStr)
##     res = map((x)->x, bytestring)
##     return res
## end

function ref(x::RArrayStr, i::Int32)
    res = @librinterface_getitem Ptr{Uint8} SexpStrVector x i
    bytestring(res)
end

function assign(x::RArrayStr, val::ASCIIString, i::Int32)
    res = @librinterface_setitem Ptr{Uint8} SexpIntVector x i val
    return res
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
        new(x)
    end
    function RFunction(x::Ptr{Void})
        new(x)
    end

end

function call{T <: Sexp}(f::RFunction, argv::Vector{T},
              argn::Vector{ASCIIString},
              env::REnvironment)
    argv_p = map((x)->x.sexp, argv)
    c_ptr = ccall(dlsym(libri, :Function_call), Ptr{Void},
                  (Ptr{Void}, Ptr{Ptr{Void}}, Int32, Ptr{Void}),
                  f, argv_p, length(argv), env)
    return _factory(c_ptr)
end
    
## # FIXME: a conversion would be possible ?
const _rl_dispatch = {
    3 => RFunction,
    4 => REnvironment,
    11 => RArrayInt32,
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
