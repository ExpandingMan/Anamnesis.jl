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


@anamnesis y = f(1.0, π)




