
type Foo{T,N}
    foo::T
    function Foo(v::Array{T, 2})
        println("inner")
        println(T)
        new(x)
    end
end

function Foo(x::Int)
    println("outer")
    Foo{Int}(x)    
end


libri = Rif.libri
v = Float64[1.1,2.2,3.3,4.4,5.5]
c_ptr = ccall(dlsym(libri, foo), Float64,
              (Ptr{Float64}, Int32),
              v, length(v))
              
