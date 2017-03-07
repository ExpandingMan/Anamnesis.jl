using Anamnesis

const dir = "anamtest"

function f(a, ϕ; b=0.0)
    println("f being called")
    a*e^(im*ϕ) + b*e^(-im*ϕ)
end


function g(a, w)
    println("g being called")
    a*tanh(w)
end




# @anamnesis y = f(1.0, π)

# expr = :(@anamnesis begin
#     y = f(1.0, π)
#     @forget g(1.0, -Inf)
#     g(1.0, Inf)
# end)

expr = :(@anamnesis dir begin
    y = f(1.0, π)
    g(1.0, -Inf)
    f(1.0, π/2)
    g(f(1.0, 0.0), Inf)
end f)
 

mac = macroexpand(expr)
 
eval(expr)


fs = @scribe(f)
gs = @scribe(g)


