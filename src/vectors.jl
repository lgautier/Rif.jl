
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

macro librinterface_matrix_new(v, classname, celltype, nx, ny)
    local f = "$(classname)_new"
    quote
        nx::Int64, ny::Int64 = ndims(v)
        c_ptr = ccall(dlsym(libri, $f), Ptr{Void},
                      (Ptr{$celltype}, Int32, Int32),
                      v, nx, ny)
        obj = new(c_ptr)
        finalizer(obj, librinterface_finalizer)
        obj
    end    
end


type RArray{T, N} <: AbstractSexp
    sexp::Ptr{Void}

    function RArray(c_ptr::Ptr{Void})
        if _typeofr(c_ptr) != _rl_map_jtor[T]
            error("Incompatible type (expected ", _rl_map_jtor[T],
                  ", get ", _typeofr(c_ptr), ").")
        end
        new(c_ptr)
    end
    
    function RArray(v::Array{Bool,1})
        @librinterface_vector_new v SexpBoolVector Bool
    end
    function RArray(v::Array{Bool,2})
        nx, ny = ndims(v)
        @librinterface_matrix_new v SexpBoolVectorMatrix Bool nx ny
    end
    function RArray(v::Array{Int32,1})
        @librinterface_vector_new v SexpIntVector Int32
    end
    function RArray(v::Array{Int32,2})
        nx, ny = ndims(v)
        @librinterface_matrix_new v SexpIntVectorMatrix Int32 nx ny
    end
    function RArray(v::Array{Float64,1})
        @librinterface_vector_new v SexpDoubleVector Float64
    end
    function RArray(v::Array{Float64,2})
        nx, ny = ndims(v)
        @librinterface_matrix_new v SexpDoubleVectorMatrix Float64 nx ny
    end
    function RArray(v::Array{ASCIIString,1})
        v_p = map((x)->pointer(x.data), v)
        @librinterface_vector_new v_p SexpStrVector Ptr{Uint8}
    end
    function RArray(v::Array{ASCIIString,2})
        nx, ny = ndims(v)
        v_p = map((x)->pointer(x.data), v)
        @librinterface_matrix_new v_p SexpStrVectorMatrix Ptr{Uint8} nx ny
    end
    function RArray{T <: Sexp}(v::Array{T,1})
        #FIXME: add constructor that builds R vectors
        #       (ideally using conversion functions)
        v_p = map((x)->pointer(x.sexp), v)
        @librinterface_vector_new v_p SexpVecVector Ptr{Void}
    end
end    

function RArray{T<:Type{Any}, N<:Integer}(t::T, n::N)
    error("Not yet implemented")
end

function names(sexp::RArray)
    c_ptr =  ccall(dlsym(libri, :Sexp_names), Ptr{Void},
                   (Ptr{Void},), sexp)
    return _factory(c_ptr)
end

function map(sexp::RArray, func::Function)
    n = length(sexp)
    res = cell(n)
    i = 1
    while i <= n
        res[i+1] = func(sexp[i])
        i += 1
    end
    res
end


## function convert(::Type{Array{ASCIIString}}, x::Type{RArray{ASCIIString}})
##     error("Not implemented")
## end

function convert(::Type{Ptr{Void}}, x::RArray)
    x.sexp
end

function convert(::Type{Sexp}, x::RArray)
    Sexp(x.sexp)
end


macro librinterface_getitem(returntype, classname, x, i)
    local f = "$(classname)_getitem"
    quote
       local res = ccall(dlsym(libri, $f), $returntype,
                         (Ptr{Void}, Int32),
                         $x.sexp, $i-1)
       if res == C_NULL
           error("Error while getting element ", $i, ".")
       end
       res
    end
end

macro librinterface_getbyname(returntype, classname, x, name)
    local f = "$(classname)_getbyname"
    quote
       local res = ccall(dlsym(libri, $f), $returntype,
                         (Ptr{Void}, Ptr{Uint8}),
                         $x.sexp, $name)
       if res == C_NULL
           error("Error while getting element `", $name, "`.")
       end
       res
    end
end


macro librinterface_setitem(valuetype, classname, x, i, value)
    local f = "$(classname)_setitem"
    quote
       local res = ccall(dlsym(libri, $f), Int32,
                         (Ptr{Void}, Int32, $valuetype),
                         $x.sexp, $i-1, $value)
       if res == -1
           error("Error while setting element ", $i, ".")
       end
       res
    end
end

macro librinterface_setbyname(valuetype, classname, x, name, value)
    local f = "$(classname)_setbyname"
    quote
       local res = ccall(dlsym(libri, $f), Int32,
                         (Ptr{Void}, Int32, $valuetype),
                         $x.sexp, $name, $value)
       if res == -1
           error("Error while setting element `", $name, "`.")
       end
       res
    end
end

# Vectors
for t = ((Bool, :SexpBoolVector),
         (Int32, :SexpIntVector),
         (Float64, :SexpDoubleVector))
    @eval begin
        # ref with Int64
        function getindex(x::RArray{$t[1], 1}, i::Int64)
            i = int32(i)
            res = @librinterface_getitem $(t[1]) $(t[2]) x i
            return res
        end
        function getindex(x::RArray{$t[1], 1}, name::ASCIIString)
            i = int32(i)
            res = @librinterface_getbyname $(t[1]) $(t[2]) x name
            return res
        end
        # ref with Int32
        function getindex(x::RArray{$t[1], 1}, i::Int32)
            res = @librinterface_getitem $(t[1]) $(t[2]) x i
            return res
        end
        function getindex(x::RArray{$t[1], 1}, name::ASCIIString)
            res = @librinterface_getbyname $(t[1]) $(t[2]) x name
            return res
        end
        # assign with Int64
        function setindex!(x::RArray{$t[1], 1}, val::$t[1], i::Int64)
            i = int32(i)
            res = @librinterface_setitem $(t[1]) $(t[2]) x i val
            return res
        end
        function setindex!(x::RArray{$t[1], 1}, val::$t[1], name::ASCIIString)
            i = int32(i)
            res = @librinterface_setbyname $(t[1]) $(t[2]) x i name
            return res
        end
        # assign with Int32
        function setindex!(x::RArray{$t[1], 1}, val::$t[1], i::Int32)
            res = @librinterface_setitem $(t[1]) $(t[2]) x i val
            return res
        end
        function setindex!(x::RArray{$t[1], 1}, val::$t[1], name::ASCIIString)
            res = @librinterface_setbyname $(t[1]) $(t[2]) x name val
            return res
        end
    end
end

macro librinterface_getitem2(returntype, classname, x, i, j)
    local f = "$(classname)_getitem"
    quote
       local res = ccall(dlsym(libri, $f), $returntype,
                         (Ptr{Void}, Int32, Int32),
                         $x.sexp, $i-1, $j-1)
       if res == C_NULL
           error("Error while getting element (", $i, ", ", $j, ").")
       end
       res
    end
end
macro librinterface_setitem2(valuetype, classname, x, i, j, value)
    local f = "$(classname)_setitem"
    quote
       local res = ccall(dlsym(libri, $f), Int32,
                         (Ptr{Void}, Int32, Int32, $valuetype),
                         $x.sexp, $i-1, $j-1, $value)
       if res == -1
           error("Error while setting element (", $i, ", ", $j, ").")
       end
       res
    end
end

# Matrices (2D arrays)
for t = ((Bool, :SexpBoolVectorMatrix),
         (Int32, :SexpIntVectorMatrix),
         (Float64, :SexpDoubleVectorMatrix))
    @eval begin
        # ref with Int64
        function getindex(x::RArray{$t[1], 2}, i::Int64, j::Int64)
            i = int32(i)
            j = int32(j)
            res = @librinterface_getitem2 $(t[1]) $(t[2]) x i j
            return res
        end
        # ref with Int32
        function getindex(x::RArray{$t[1], 2}, i::Int32, j::Int32)
            res = @librinterface_getitem2 $(t[1]) $(t[2]) x i j
            return res
        end
        # assign with Int64
        function setindex!(x::RArray{$t[1], 2}, val::$t[1], i::Int64, j::Int64)
            i = int32(i)
            j = int32(j)
            res = @librinterface_setitem2 $(t[1]) $(t[2]) x i j val
            return res
        end
        # assign with Int32
        function setindex!(x::RArray{$t[1], 2}, val::$t[1], i::Int32, j::Int32)
            res = @librinterface_setitem2 $(t[1]) $(t[2]) x i j val
            return res
        end
    end
end


# array of strings
function getindex(x::RArray{ASCIIString, 1}, i::Int64)
    i = int32(i)
    c_ptr = @librinterface_getitem Ptr{Uint8} SexpStrVector x i
    bytestring(c_ptr)
end
function getindex(x::RArray{ASCIIString, 2}, i::Int64, j::Int64)
    i = int32(i)
    j = int32(j)
    c_ptr = @librinterface_getitem2 Ptr{Uint8} SexpStrVectorMatrix x i j
    bytestring(c_ptr)
end

function getindex(x::RArray{ASCIIString, 1}, i::Int32)
    c_ptr = @librinterface_getitem Ptr{Uint8} SexpStrVector x i
    bytestring(c_ptr)
end
function setindex!(x::RArray{ASCIIString}, val::ASCIIString, i::Int64)
    i = int32(i)
    res = @librinterface_setitem Ptr{Uint8} SexpIntVector x i val
    return res
end
function setindex!(x::RArray{ASCIIString}, val::ASCIIString, i::Int32)
    res = @librinterface_setitem Ptr{Uint8} SexpIntVector x i val
    return res
end

# list
function getindex(x::RArray{AbstractSexp, 1}, i::Int64)
    i = int32(i)
    c_ptr = @librinterface_getitem Ptr{Void} SexpVecVector x i
    _factory(c_ptr)
end

function getindex(x::RArray{AbstractSexp, 1}, i::Int32)
    c_ptr = @librinterface_getitem Ptr{Void} SexpVecVector x i
    _factory(c_ptr)
end
function getindex(x::RArray{AbstractSexp, 1}, name::ASCIIString)
    c_ptr = @librinterface_getbyname Ptr{Void} SexpVecVector x name
    _factory(c_ptr)
end


function assign{T <: AbstractSexp}(x::RArray{AbstractSexp}, val::T, i::Int32)
    res = @librinterface_setbyname Ptr{Void} SexpVecVector x i val
    return res
end
function assign{T <: AbstractSexp}(x::RArray{AbstractSexp}, val::T, name::ASCIIString)
    res = @librinterface_setbyname Ptr{Void} SexpVecVector x name val
    return res
end

