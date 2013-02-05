module Rif

using Base
#import Base.dlopen, Base.dlsym, Base.length
import Base.assign, Base.ref,
       Base.convert,
       Base.eltype,
       Base.length, Base.map

require("DataFrames")
import DataFrames.AbstractDataArray


export initr, isinitialized, isbusy, hasinitargs, setinitargs, getinitargs,
       REnvironment, RFunction,
       RArray,
       Sexp, AbstractSexp,
       RDataArray, AbstractRDataArray,
       ref, assign, map, del,
       call, names, ndims,
       convert,
       getGlobalEnv, getBaseEnv,
       parseR, evalR,
       Rinenv,
       R,
       # utilities (wrapping R functions)
       requireR, cR,
       # macros
       @R, @RINIT, @R_str,
       @_RL_TYPEOFR,
       # hack
       Rp

_do_rebuild = false

function _packpath(dir::String, name::String)
    return joinpath(Pkg.dir(), "Rif", dir, name)
end

function _packpath(dir::String)
    return joinpath(Pkg.dir(), "Rif", dir)
end

dllpath = _packpath("deps", "librinterface.so")

if isfile(dllpath)
    for csourcename in ("librinterface.c", )
        csourcepath = _packpath("deps", csourcename)
        if  Base.stat(dllpath).mtime < Base.stat(csourcepath).mtime
            println("************************************************************")
            println("librinterface.so is older than librinterface.c; compiling...")
            println("************************************************************")
            _do_rebuild = true
            break
        end
    end
else
    println("*********************************************************")
    println("Can't find librinterface.so; attempting to compile...    ")
    println("*********************************************************")
    _do_rebuild = true
end    
if _do_rebuild
    cd(_packpath("deps")) do
    run(`make all`) 
    end
    println("*********************************************************")
    println("Compiling complete")
    println("*********************************************************")
end

include(_packpath("src","embeddedr.jl"))
include(_packpath("src", "sexp.jl"))

const _rl_map_rtoj = {
    LGLSXP => Bool,
    INTSXP => Int32,
    REALSXP => Float64,
    STRSXP => ASCIIString,
    VECSXP => Sexp
                      }
                      
const _rl_map_jtor = {
    Bool => LGLSXP,
    Int32 => INTSXP,
    Float64 => REALSXP,
    ASCIIString => STRSXP,
    Sexp => VECSXP
                      }
include(_packpath("src", "vectors.jl"))
#FIXME: at some point the content of dataframes.jl will supersede the one
#       of vectors.jl
include(_packpath("src", "dataframes.jl"))

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

#FIXME: Why isn't this working ?
## function convert(::Vector{ASCIIString}, x::Type{RArrayStr})
##     n = length(x)
##     res = Array(ASCIIString, n)
##     i = 1
##     while i <= n
##         res[i] = x[i-1]
##         i += 1
##     end
##     res
## end

## function convert(::Array{ASCIIString}, x::RArrayStr)
##     res = map((x)->x, bytestring)
##     return res
## end


include(_packpath("src", "environments.jl"))

include(_packpath("src", "functions.jl"))

type RExpression <: AbstractSexp
    sexp::Ptr{Void}
    function RExpression(x::Sexp)
        new(x)
    end
    function RExpression(x::Ptr{Void})
        new(x)
    end    
end

type RS4 <: AbstractSexp
    sexp::Ptr{Void}

    function RS4(x::Ptr{Void})
        new(x)
    end

    function RS4(x::Sexp)
        new(x)
    end    
end


## # FIXME: a conversion would be possible ?
const _rl_dispatch = {
    CLOSXP => RFunction,
    BUILTINSXP => RFunction,
    ENVSXP => REnvironment,
    EXPRSXP => RExpression,
    LGLSXP => RArray,
    INTSXP => RArray,
    REALSXP => RArray,
    STRSXP => RArray,
    VECSXP => RArray,
    S4SXP => RS4
    }

function _factory(c_ptr::Ptr{Void})
    rtype::Int =  @_RL_TYPEOFR(c_ptr)
    if rtype == NILSXP
        return None
    end
    jtype = _rl_dispatch[rtype]
    if jtype == RArray
        ndims::Int =  ccall(dlsym(libri, :Sexp_ndims), Int,
                            (Ptr{Void},), c_ptr)
        res = RArray{_rl_map_rtoj[rtype], ndims}(c_ptr)
    else
        res = jtype(c_ptr)
    end
    return res
end

## FIXME: not working
## conversions 
# scalars
for t = (Bool, Int32, Float64, ASCIIString)
    @eval begin
        function convert(::RArray{$t, 1}, x::$t)
                RArray{$t, 1}([x])
        end
    end
end
# vectors and matrices
for t = (Bool, Int32, Float64, ASCIIString)
    @eval begin
        function convert(::RArray{$t, 1}, x::Array{$t, 1})
            RArray{$t, 1}(x)
        end
        function convert(::RArray{$t, 2}, x::Array{$t, 2})
            RArray{$t, 2}(x)
        end
    end
end
###
## FIXME: hack to overcome loose type inference
function Rp(d::Dict{ASCIIString})
    res = Dict{ASCIIString, Sexp}()
    for (k, v) in d
        res[k] = v
    end
    res
end




type NamedValue
    name::ASCIIString
    value::Any
end


function parseR(x::ASCIIString)
    c_ptr = ccall(dlsym(libri, :EmbeddedR_parse),
                  Ptr{Void},
                  (Ptr{Uint8},),
                  x)
    if c_ptr == C_NULL
        if ! bool(@_RL_INITIALIZED)
            error("R is not initialized")
        end
        error("Error evaluating the R expression.")
    end
    return _factory(c_ptr)
end

function evalR(x::RExpression)
    ge = getGlobalEnv()
    c_ptr = ccall(dlsym(libri, :EmbeddedR_eval),
                  Ptr{Void},
                  (Ptr{Void}, Ptr{Void}),
                  x.sexp, ge.sexp)
    if c_ptr == C_NULL
        error("Error evaluating the R expression.")
    end
    return _factory(c_ptr)
end

function Rinenv(sym::Symbol, env::REnvironment)
    return NamedValue("$sym", get(env, "$sym"))
end
# FIXME: if not symbol, means a local Julia variable ?


function R(string::ASCIIString)
    e = parseR(string)
    evalR(e)
end

macro RINIT(argv::Vector{ASCIIString})
    setinitargs(argv)
    # initialize embedded R
    initr()
end
    
#macro R_str(code::ASCIIString)
#    ## R must be initialized (macro RINIT), or the call to parseR will fail
#    e = parseR(code)
#    expr(quote, e)
#end

function Rinenv(expr::Expr, env::REnvironment)
    if expr.head == :call
        print("Call: ")
        # function call
        func_sym = expr.args[1].head
        # sanity check (in case I missed something)
        if typeof(func_sym) != Symbol
            error("Expected a symbol but get ", func_sym)
        end
        rfunc = get(env, "$func_sym")
        # next are arguments
        i = 2
        n = length(expr.args)
        if (n == 1)
            error("Expression of unsufficient length: ", expr)
        end
        eargv = Array(Sexp, n-1)
        eargn = Array(ASCIIString, n-1)
        println("n = ", n)
        println("expr.args = ", expr.args)
        while i <= n
            a = expr.args[i]
            elt = Rinenv(a, env)
            eargn[i-1] = elt.name
            eargv[i-1] = elt.value
            i += 1
        end
        e = Expr(:call, {call, rfunc, eargv, eargn, env}, Any)
        return e
    elseif expr.head == :tuple
        #FIXME: can this occur ?
    elseif expr.head == :(:=)
        # named variable
        if length(expr.args) != 2
            error("Expected an expression of length 2 and got: ", expr)
        end
        v_name = "$(expr.args[1])"
        v_value = expr.args[2]
        return NamedValue(v_name, v_value)
    end
    error("We should not be here with: ", expr)
end


macro R(expression)
    local ge = getGlobalEnv()
    quote
        Rinenv($expression, $ge)
    end
end

function cR(obj...)
  a = [obj...]
  t = eltype(a)
  if t == Int64
      a = Int32[a...]
      t = Int32
  end
  RArray{t,1}(a)
end

function requireR(name::ASCIIString)
    e = parseR("require(" * name * ")")
    evalR(e)
end

end
