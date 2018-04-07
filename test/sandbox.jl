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


