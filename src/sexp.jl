
abstract AbstractSexp

#    sexp::Ptr{Void}

type Sexp <: AbstractSexp
    sexp::Ptr{Void}
    function Sexp(c_ptr::Ptr{Void})
        obj = new(c_ptr)
        finalizer(obj, librinterface_finalizer)
        obj
    end
end
    
macro _RL_TYPEOFR(c_ptr)
    quote
        ccall(dlsym(libri, :Sexp_typeof), Int,
              (Ptr{Void},), $c_ptr)
    end
end


#FIXME: is there any user for this in the end ?
RVectorTypes = Union(Bool, Int32, Float64, ASCIIString)

function librinterface_finalizer(sexp::AbstractSexp)
    ccall(dlsym(libri, :R_ReleaseObject), Void,
          (Ptr{Void},), sexp)
end
    
function named(sexp::AbstractSexp)
    res =  ccall(dlsym(libri, :Sexp_named), Int,
                 (Ptr{Void},), sexp)
    return res
end

function typeofr(sexp::AbstractSexp)
    res::Int =  @_RL_TYPEOFR(sexp.sexp)
    return res
end

function _typeofr(sexp_ptr::Ptr{Void})
    res::Int =  @_RL_TYPEOFR(sexp_ptr)
    return res
end

function length(sexp::AbstractSexp)
    res =  ccall(dlsym(libri, :Sexp_length), Int,
                 (Ptr{Void},), sexp)
    return res
end

function ndims(sexp::AbstractSexp)
    res =  ccall(dlsym(libri, :Sexp_ndims), Int,
                 (Ptr{Void},), sexp)
    return res
end

function getAttr(sexp::AbstractSexp, name::ASCIIString)
    c_ptr =  ccall(dlsym(libri, :Sexp_getAttribute), Ptr{Void},
                 (Ptr{Void}, Ptr{Uint8}),
                 sexp.sexp, name)
    if c_ptr == C_NULL
        error("No such attribute: ", name)
    end
    Sexp(c_ptr)
end



function convert{T <: Sexp}(::Type{Ptr{Void}}, x::T)
    x.sexp
end
