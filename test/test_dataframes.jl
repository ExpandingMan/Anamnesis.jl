using Anamnesis
using DataFrames

const dir = "anamtest"

function m(seed::Integer)
    println("m being called")
    srand(seed)
    DataFrame(A=rand(10), B=rand(10))
end


# df = @anamnesis dir m(5)
df = @anamnesis dir m(5)

ms = @scribe(m)

