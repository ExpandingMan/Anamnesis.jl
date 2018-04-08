using Anamnesis
using BenchmarkTools

function f(x)
    println("f being called!")
    x^2 + 1
end

function g(x; y) 
    println("g being called!")
    x^2 + y
end

@anamnesis function h(x::Int; y::Float64=1)
    println("h being called!")
    x^2 + y
end

@anamnesis begin
    a = 1
    b = 2
    z(v) = sum(v)
    f(a)
    f(b)
    println("!!  ", f(a) + f(b))
    println("!!  ", z([1,2,3]))
    g(a, y=b)
    g(a, y=b)
end f g


