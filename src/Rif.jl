module Rif

using Base
#import Base.dlopen, Base.dlsym, Base.length
import Base.assign, Base.ref, Base.convert, Base.length, Base.map

export initr, isinitialized, isbusy, hasinitargs, setinitargs, getinitargs,
       REnvironment, RFunction,
       RArrayInt32, RArrayFloat64, RArrayStr, RArrayVec,
       ref, assign, map, del,
       call, names,
       convert,
       getGlobalEnv, getBaseEnv,
       Rinenv, @R

       
dllname = julia_pkgdir() * "/Rif/deps/librinterface.so"
if !isfile(dllname)
    println("*****************************************************")
    println("Can't find librinterface.so; attempting to compile...")
    println("*****************************************************")
    cd(julia_pkgdir() * "/Rif/deps") do
        run(`make all`) 
    end
    println("*****************************************************")
    println("Compiling complete")
    println("*****************************************************")
end    

libri = dlopen(julia_pkgdir() * "/Rif/deps/librinterface")


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

function librinterface_finalizer(sexp::Sexp)
    ccall(dlsym(libri, :R_ReleaseObject), Void,
          (Ptr{Void},), sexp)
end
    
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

function names{T <: SexpArray}(sexp::T)
    c_ptr =  ccall(dlsym(libri, :Sexp_names), Ptr{Void},
                   (Ptr{Void},), sexp)
    return _factory(c_ptr)
end


const _rl_map = {
    #3 => RFunction,
    #4 => REnvironment,
    10 => (n)->Array(Bool, n), #LGLINTSXP
    11 => (n)->Array(Int32, n), #INTSXP
    14 => (n)->Array(Float64, n), #REALSXP
    16 => (n)->Array(ASCIIString, n), #STRSXP
    19 => cell #VECSXP                            
                     }
function map{T <: SexpArray}(sexp::T, func::Function)
    n = length(sexp)
    res = cell(n)
    i = 0
    #FIXME: 1-offset indexing for Julia arrays !
    while i < n
        res[i+1] = func(sexp[i])
        i += 1
    end
    res
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
const INTSXP  = uint(13)
const REALSXP  = uint(14)
const STRSXP  = uint(16)
const VECSXP  = uint(19)
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

macro librinterface_vector_new(v, classname, celltype)
    local f = "$(classname)_new"
    quote
        c_ptr = ccall(dlsym(libri, $f), Ptr{Void},
                      (Ptr{$celltype}, Int32),
                      v, length(v))
        obj = new(c_ptr)
        finalizer(obj, librinterface_finalizer)
        obj
    end
end


type RArrayInt32 <: SexpArray
    sexp::Ptr{Void}
    function RArrayInt32(c_ptr::Ptr{Void})
        if _rtype(c_ptr) != INTSXP
            error("Incompatible type (expected ", INTSXP,
                  ", get ", _rtype(c_ptr), ").")
        end
        new(c_ptr)
    end
    function RArrayInt32(v::Vector{Int32})
        @librinterface_vector_new v SexpIntVector Int32
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

macro librinterface_getvalue(returntype, classname, x, i)
    local f = "$(classname)_getvalue"
    quote
       local res = ccall(dlsym(libri, $f), $returntype,
                         (Ptr{Void}, Ptr{Uint8}),
                         $x.sexp, $i)
       if res == C_NULL
           error("Error while getting element ", $i, ".")
       end
       res
    end
end

macro librinterface_setvalue(valuetype, classname, x, i, value)
    local f = "$(classname)_setvalue"
    quote
       local res = ccall(dlsym(libri, $f), Int32,
                         (Ptr{Void}, Ptr{Uint8}, $valuetype),
                         $x.sexp, $i, $value)
       if res == -1
           error("Error while setting element ", $i, ".")
       end
       res
    end
end


function ref(x::RArrayInt32, i::Int64)
    i = int32(i)
    res = @librinterface_getitem Int32 SexpIntVector x i
    return res
end

function ref(x::RArrayInt32, i::Int32)
    res = @librinterface_getitem Int32 SexpIntVector x i
    return res
end

#function convert
#    c_ptr = ccall(dlsym(libri, :SexpIntVector_ptr), Ptr{Int32},
#                  (Ptr{Void},),
#                  res.sexp)

function assign(x::RArrayInt32, val::Int32, i::Int64)
    i = int32(i)
    res = @librinterface_setitem Int32 SexpIntVector x i val
    return res
end
function assign(x::RArrayInt32, val::Int32, i::Int32)
    res = @librinterface_setitem Int32 SexpIntVector x i val
    return res
end

# -- Bool
type RArrayBool <: SexpArray
    sexp::Ptr{Void}
    function RArrayBool(c_ptr::Ptr{Void})
        if _rtype(c_ptr) != LGLSXP
            error("Incompatible type (expected ", LGLSXP,
                  ", get ", _rtype(c_ptr), ").")
        end
        new(c_ptr)
    end
    function RArrayBool(v::Vector{Bool})
        @librinterface_vector_new v SexpBoolVector Bool
    end    
end    

function ref(x::RArrayBool, i::Int64)
    i = int32(i)
    res = @librinterface_getitem Bool SexpBoolVector x i
    return res
end

function ref(x::RArrayBool, i::Int32)
    res = @librinterface_getitem Bool SexpBoolVector x i
    return res
end

function assign(x::RArrayBool, val::Bool, i::Int64)
    i = int32(i)
    res = @librinterface_setitem Bool SexpBoolVector x i val
    return res
end
function assign(x::RArrayBool, val::Bool, i::Int32)
    res = @librinterface_setitem Bool SexpBoolVector x i val
    return res
end

# -- Float64
type RArrayFloat64 <: SexpArray
    sexp::Ptr{Void}
    function RArrayFloat64(c_ptr::Ptr{Void})
        if _rtype(c_ptr) != REALSXP
            error("Incompatible type.")
        end
        new(c_ptr)
    end
    function RArrayFloat64(v::Vector{Float64})
        @librinterface_vector_new v SexpDoubleVector Float64 
    end
end    

function ref(x::RArrayFloat64, i::Int64)
    i = int32(i)
    res = @librinterface_getitem Float64 SexpDoubleVector x i
    return res
end
function ref(x::RArrayFloat64, i::Int32)
    res = @librinterface_getitem Float64 SexpDoubleVector x i
    return res
end

function assign(x::RArrayFloat64, val::Float64, i::Int32)
    res = @librinterface_setitem Float64 SexpIntVector x i val
    return res
end
function assign(x::RArrayFloat64, val::Float64, i::Int64)
    i = int32(i)
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
        v_p = map((x)->pointer(x.data), v)
        @librinterface_vector_new v_p SexpStrVector Uint8 
    end

end

#FIXME: Why isn't this working ?
function convert(::Vector{ASCIIString}, x::Type{RArrayStr})
    n = length(x)
    res = Array(ASCIIString, n)
    i = 1
    while i <= n
        res[i] = x[i-1]
        i += 1
    end
    res
end

## function convert(::Array{ASCIIString}, x::RArrayStr)
##     res = map((x)->x, bytestring)
##     return res
## end

function ref(x::RArrayStr, i::Int64)
    i = int32(i)
    res = @librinterface_getitem Ptr{Uint8} SexpStrVector x i
    bytestring(res)
end
function ref(x::RArrayStr, i::Int32)
    res = @librinterface_getitem Ptr{Uint8} SexpStrVector x i
    bytestring(res)
end

function assign(x::RArrayStr, val::ASCIIString, i::Int64)
    i = int32(i)
    res = @librinterface_setitem Ptr{Uint8} SexpIntVector x i val
    return res
end
function assign(x::RArrayStr, val::ASCIIString, i::Int32)
    res = @librinterface_setitem Ptr{Uint8} SexpIntVector x i val
    return res
end

type RArrayVec <: SexpArray
    sexp::Ptr{Void}
    function RArrayVec(c_ptr::Ptr{Void})
        if _rtype(c_ptr) != VECSXP
            error("Incompatible type.")
        end
        new(c_ptr)
    end
    function RArrayVec{T <: Sexp}(v::Vector{T})
        #FIXME: add constructor that builds R vectors
        #       (ideally using conversion functions)
        v_p = map((x)->pointer(x.sexp), v)
        @librinterface_vector_new v_p SexpVecVector Void 
    end
end

function ref(x::RArrayVec, i::Int64)
    i = int32(i)
    c_ptr = @librinterface_getitem Ptr{Void} SexpVecVector x i
    _factory(c_ptr)
end
function ref(x::RArrayVec, i::Int32)
    c_ptr = @librinterface_getitem Ptr{Void} SexpVecVector x i
    _factory(c_ptr)
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

function ref(x::REnvironment, i::ASCIIString)
    c_ptr = @librinterface_getvalue Ptr{Void} SexpEnvironment x i
    return _factory(c_ptr)
end

function assign{T <: Sexp}(x::REnvironment, val::T, i::ASCIIString)
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


type RFunction <: Sexp
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
    return _factory(c_ptr)
end



## # FIXME: a conversion would be possible ?
const _rl_dispatch = {
    3 => RFunction,
    4 => REnvironment,
    13 => RArrayInt32,
    14 => RArrayFloat64,
    16 => RArrayStr,
    19 => RArrayVec
                      }

function _factory(c_ptr::Ptr{Void})
    rtype::Int =  ccall(dlsym(libri, :Sexp_typeof), Int,
                   (Ptr{Void},), c_ptr)
    res = _rl_dispatch[rtype](c_ptr)
    return res
end

#FIXME: implement get for UTF8 symbols
function get(environment::REnvironment, symbol::ASCIIString)
    c_ptr = ccall(dlsym(libri, :SexpEnvironment_get), Ptr{Void},
                 (Ptr{Void}, Ptr{Uint8}),
                environment.sexp, symbol)
    # evaluate if promise
    if _rtype(c_ptr) == PROMSXP
        c_ptr = ccall(dlsym(libri, :Sexp_evalPromise), Ptr{Void},
                      (Ptr{Void},), c_ptr)
    end
        
    return _factory(c_ptr)
end


function Rinenv(expr::Expr, env::REnvironment)
    if typeof(expr) == Symbol
        # unnamed symbol, used untouched 
        #FIXME: automagic conversion ?
        print("Symbol: ", expr)
        return expr
    elseif expr.head == :call
        print("Call: ")
        # function call
        func_sym = expr.args[1]
        # sanity check (in case I missed something)
        if typeof(func_sym) != Symbol
            error("Expected a symbol")
        end
            rfunc = get(env, "$func_sym")
        # next are arguments
        i = 2
        n = length(exprs.args)
        #FIXME: what if n == 1 ?
        error("Expression of unsufficient length: ", expr)
        eargv = Array(Any, n-1)
        eargn = Array(ASCIIString, n-1)
        while i < n
            a = expr.args[i]
            elt = Rinenv(a, env)
            eargs[i-1] = elt
        end
        @eval expr(func_sym, eargs)
    elseif expr.head == :tuple
        #FIXME: can this occur ?
    elseif expr.head == :(:=)
        # named variable
        if length(expr.args) != 2
            error("Expected an expression of length 2 and got: ", expr)
        end
        v_name = expr.args[1]
        print(v_name)
        v_value = expr.args[2]
    end
    error("We should not be here with: ", expr)
end


macro R(expr)
    ge = getGlobalEnv()
    Rinenv(expr, ge)
end

end
