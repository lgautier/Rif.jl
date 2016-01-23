using Compat
using DataFrames
import DataFrames.AbstractDataArray
import DataFrames.DataArray

import Base.size
import Base.similar

abstract AbstractRDataArray{T,N} <: AbstractDataArray{T,N}

macro librinterface_vector_new(v, classname, celltype)
    local f = "$(classname)_new"
    quote
    end
end

_rtype2cconstructor = @compat Dict(Bool => :SexpBoolVector_new,
                                   Int32 => :SexpIntVector_new,
                                   Float64 => :SexpDoubleVector_new)


type RDataArray{T, N} <: AbstractRDataArray{T,N}
    # in the absence of multiple inheritance, the chosen
    # parent is DataFrame and the Sexp is made an attribute
    # with converters
    sexp::Ptr{Void}
    na::BitArray{N}

    function RDataArray(d::Array{T, N}, m::BitArray{N})
        if size(d) != size(m)
            msg = "Data and missingness arrays must be the same size"
            throw(ArgumentError(msg))
        end
        c_ptr = ccall(dlsym(libri, _rtype2cconstructor[T]), Ptr{Void},
                      (Ptr{T}, Int32),
                      d, length(d))
        obj = new(c_ptr, m)
        finalizer(obj, librinterface_finalizer)
        obj
    end

    function RDataArray(c_ptr::Ptr{Void})
        if _typeofr(c_ptr) != _rl_map_jtor[T]
            error("Incompatible type (expected ", _rl_map_jtor[T],
                  ", get ", _typeofr(c_ptr), ").")
        end
        obj = new(c_ptr)
        finalizer(obj, librinterface_finalizer)
        obj
    end

    function RDataArray(v::DataArray{Bool,1})
        @librinterface_vector_new v SexpBoolVector Bool
    end
    function RDataArray(v::DataArray{Bool,2})
        nx, ny = ndims(v)
        @librinterface_matrix_new v SexpBoolVectorMatrix Bool nx ny
    end
    function RDataArray(v::DataArray{Int32,1})
        @librinterface_vector_new v SexpIntVector Int32
    end
    function RDataArray(v::DataArray{Int32,2})
        nx, ny = ndims(v)
        @librinterface_matrix_new v SexpIntVectorMatrix Int32 nx ny
    end
    function RDataArray(v::DataArray{Float64,1})
        @librinterface_vector_new v SexpDoubleVector Float64
    end
    function RDataArray(v::DataArray{Float64,2})
        nx, ny = ndims(v)
        @librinterface_matrix_new v SexpDoubleVectorMatrix Float64 nx ny
    end
    function RDataArray(v::DataArray{ASCIIString,1})
        v_p = map((x)->pointer(x.data), v)
        @librinterface_vector_new v_p SexpStrVector Ptr{Uint8}
    end
    function RDataArray(v::DataArray{ASCIIString,2})
        nx, ny = ndims(v)
        v_p = map((x)->pointer(x.data), v)
        @librinterface_matrix_new v_p SexpStrVectorMatrix Ptr{Uint8} nx ny
    end
    function RDataArray{A <: Sexp}(v::DataArray{A,1})
        #FIXME: add constructor that builds R vectors
        #       (ideally using conversion functions)
        v_p = map((x)->pointer(x.sexp), v)
        @librinterface_vector_new v_p SexpVecVector Ptr{Void}
    end
end


macro librinterface_vector_new_nofill(n, classname, celltype)
    local f = "$(classname)_new_nofill"
    quote
        c_ptr = ccall(dlsym(libri, $f), Ptr{Void},
                      (Int32,),
                      $n)
        c_ptr
    end
end


## Aliases for vectors and matrixes
typealias AbstractRDataVector{T} AbstractRDataArray{T, 1}
typealias AbstractRDataMatrix{T} AbstractRDataArray{T, 2}
typealias RDataVector{T} RDataArray{T, 1}
typealias RDataMatrix{T} RDataArray{T, 2}


## Constructors
for e = ((Bool, :SexpBoolVector),
         (Int32, :SexpIntVector),
         (Float64, :SexpDoubleVector))
    @eval begin
        function RDataArray(t::Type{$(e[1])}, dims::Integer)
            dims = convert(Int32, dims)
            res = @librinterface_vector_new_nofill dims $(e[2]) $(e[1])
            RDataArray{$(e[1]),1}(res)
        end
    end
end



convert(::Type{Sexp}, x::AbstractRDataArray) = Sexp(x.sexp)

## Methods from Sexp
function named(x::AbstractRDataArray)
    named(convert(Sexp, x))
end

function typeofr(x::AbstractRDataArray)
    typeof(convert(Sexp, x))
end

function getAttr(sexp::AbstractRDataArray, name::ASCIIString)
    getAttr(convert(Sexp, sexp), name)
end

#FIXME: trace the problem with show()
function show(x::AbstractRDataArray)
    println("That's a temporary show()...")
    show(convert(Any, x))
end

## Copying
copy(x::RDataArray) = error("Not implemented")
deepcopy(x::RDataArray) = error("Not implemented")

## Similar
similar(x::RDataArray) = x # copied from DataFrames.jl (not sure about what I am doing)

function similar{T}(x::RDataArray{T}, dims::Int...)
    RDataArray(Array(T, dims...), trues(dims...))
end

function similar{T}(x::RDataArray{T}, dims::Dims)
    RDataArray(Array(T, dims), trues(dims))
end



## Size and dimensions

function size(x::RDataArray)
    try
        getAttr(x, "dims")
    catch
        (length(x), )
    end
end
length(x::AbstractRDataArray) = length(convert(Sexp, x))
ndims(x::AbstractRDataArray) = ndims(convert(Sexp, x))
# difference between endof() and length() ?
endof(x::RDataArray) = error("Not implemented")
eltype{T, N}(x::RDataArray{T, N}) = T

# Vectors
for t = ((Bool, :SexpBoolVector),
         (Int32, :SexpIntVector),
         (Float64, :SexpDoubleVector))
    @eval begin
        function getindex(x::RDataArray{$t[1], 1}, i::Integer)
            i32 = int32(i)
            res = @librinterface_getitem $(t[1]) $(t[2]) x i32
            return res
        end
        function setindex!(x::RDataArray{$t[1], 1}, val::$t[1],
                        i::Integer)
            i = convert(Int32, i)
            res = @librinterface_setitem $(t[1]) $(t[2]) x i val
            return res
        end
    end
end

# Matrices
for t = ((Bool, :SexpBoolVectorMatrix),
         (Int32, :SexpIntVectorMatrix),
         (Float64, :SexpDoubleVectorMatrix))
    @eval begin
        function getindex(x::RDataArray{$t[1], 2}, i::Integer, j::Integer)
            i = convert(Int32, i)
            j = convert(Int32, j)
            res = @librinterface_getitem2 $(t[1]) $(t[2]) x i j
            return res
        end
        function setindex!(x::RDataArray{$t[1], 2}, val::$t[1],
                        i::Integer, j::Integer)
            i = convert(Int32, i)
            j = convert(Int32, j)
            res = @librinterface_setitem2 $(t[1]) $(t[2]) x i j val
            return res
        end
    end
end


# array of strings
function getindex(x::RDataArray{ASCIIString, 1}, i::Integer)
    i = convert(Int32, i)
    c_ptr = @librinterface_getitem Ptr{Uint8} SexpStrVector x i
    bytestring(c_ptr)
end
function getindex(x::RDataArray{ASCIIString, 2}, i::Integer, j::Integer)
    i = convert(Int32, i)
    j = convert(Int32, j)
    c_ptr = @librinterface_getitem2 Ptr{Uint8} SexpStrVectorMatrix x i j
    bytestring(c_ptr)
end

function setindex!(x::RDataArray{ASCIIString}, val::ASCIIString, i::Integer)
    i = convert(Int32, i)
    res = @librinterface_setitem Ptr{Uint8} SexpIntVector x i val
    return res
end


@compat RListType = Union{AbstractSexp, AbstractRDataArray}
#RListType = Union(AbstractRDataArray)

# list
function getindex(x::RDataArray{RListType, 1}, i::Integer)
    i = convert(Int32, i)
    c_ptr = @librinterface_getitem Ptr{Void} SexpVecVector x i
    _factory(c_ptr)
end

function getindex(x::RDataArray{RListType, 1}, name::ASCIIString)
    c_ptr = @librinterface_getbyname Ptr{Void} SexpVecVector x name
    _factory(c_ptr)
end


function assign{T <: RListType}(x::RDataArray{RListType},
                                val::T, i::Integer)
    i = convert(Int32, i)
    res = @librinterface_setbyname Ptr{Void} SexpVecVector x i val
    return res
end
function assign{T <: RListType}(x::RDataArray{RListType},
                                val::T, name::ASCIIString)
    res = @librinterface_setbyname Ptr{Void} SexpVecVector x name val
    return res
end
