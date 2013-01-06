abstract Sexp
#    sexp::Ptr{Void}

macro _RL_TYPEOFR(c_ptr)
    quote
        ccall(dlsym(libri, :Sexp_typeof), Int,
              (Ptr{Void},), $c_ptr)
    end
end


#FIXME: is there any user for this in the end ?
RVectorTypes = Union(Bool, Int32, Float64, ASCIIString)

function librinterface_finalizer(sexp::Sexp)
    ccall(dlsym(libri, :R_ReleaseObject), Void,
          (Ptr{Void},), sexp)
end
    
function named(sexp::Sexp)
    res =  ccall(dlsym(libri, :Sexp_named), Int,
                 (Ptr{Void},), sexp)
    return res
end

function named(sexp::Sexp)
    res =  ccall(dlsym(libri, :Sexp_named), Int,
                 (Ptr{Void},), sexp)
    return res
end

function typeofr(sexp::Sexp)
    res::Int =  @_RL_TYPEOFR(sexp.sexp)
    return res
end

function _typeofr(sexp_ptr::Ptr{Void})
    res::Int =  @_RL_TYPEOFR(sexp_ptr)
    return res
end

function length(sexp::Sexp)
    res =  ccall(dlsym(libri, :Sexp_length), Int,
                 (Ptr{Void},), sexp)
    return res
end

function ndims(sexp::Sexp)
    res =  ccall(dlsym(libri, :Sexp_ndims), Int,
                 (Ptr{Void},), sexp)
    return res
end


function convert{T <: Sexp}(::Type{Ptr{Void}}, x::T)
    x.sexp
end
