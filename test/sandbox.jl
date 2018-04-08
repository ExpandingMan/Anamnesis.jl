using Anamnesis
using BenchmarkTools
using Random, LinearAlgebra

dtype = ComplexF64

callcount = [0, 0]
f = (x::AbstractVector{<:Number}) -> (callcount[1] += 1; x⋅x + 1)
sf = Scribe(f, IdDict())


x = rand(dtype, rand(64:256))
ξ = rand(dtype)
y = randstring(rand(0:31))

sf(x) == f(x)

# sg(ξ, y=y) == g(ξ, y=y)
# sf(x) == f(x)
# sg(ξ, y=y) == g(ξ, y=y)

ex = @macroexpand @anamnesis begin
        f2([1,2]) + h2(3)
        z = f2([1,2]) + h2(3)
        string(g2(1, y="fire"), g2(2, y="walk"), h2("with"), h2("me"))
        A = [h2("with") g2(1,y="fire")
             g2(2,y="walk") h2("me")]
end f2 g2
