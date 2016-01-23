
# Parent class for all R objects exposed
abstract AbstractSexp

# Unspecified R object
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
@compat RVectorTypes = Union{Bool, Int32, Float64, ASCIIString}

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

function setAttr!(sexp::AbstractSexp, name::ASCIIString,
                  sexp_attr::AbstractSexp)
    c_ptr =  ccall(dlsym(libri, :Sexp_setAttribute), Ptr{Void},
                 (Ptr{Void}, Ptr{Uint8}, Ptr{Void}),
                 sexp.sexp, name, sexp_attr.sexp)
end


function convert{T <: Sexp}(::Type{Ptr{Void}}, x::T)
    x.sexp
end

function convert(::Type{Sexp}, b::Bool)
    RArray{Bool, 1}(Bool[b])
end

function convert(::Type{Sexp}, i::Int)
    RArray{Int32, 1}(Int32[i])
end

function convert(::Type{Sexp}, f::Number)
    RArray{Float64, 1}(Float64[f])
end

function convert(::Type{Sexp}, s::ASCIIString)
    RArray{ASCIIString, 1}(ASCIIString[s])
end

function convert{T <: AbstractSexp}(::Type{Sexp}, o::T)
    Sexp(o.sexp)
end

function convert{T,N}(::Type{Sexp}, v::Array{T,N})
    RArray{T, N}(v)
end
