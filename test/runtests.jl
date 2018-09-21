using Anamnesis
using Test, Random, LinearAlgebra

Random.seed!(999)

const NUMBER_TYPES = [Int, UInt, Float64, Complex{Float64}]

const N_CALL_LOOPS = 32

@testset "Scribe" begin
    for dtype ∈ NUMBER_TYPES
        callcount = [0, 0]
        f = (x::AbstractVector{<:Number}) -> (callcount[1] += 1; x⋅x + 1)
        sf = Scribe(f)
        g = (x::Number; y::String) -> (callcount[2] += 1; x + length(y))
        sg = Scribe(g)

        for i ∈ 1:N_CALL_LOOPS
            x = rand(dtype, rand(64:256))
            ξ = rand(dtype)
            y = randstring(rand(0:31))
            @test sf(x) == f(x)
            @test sg(ξ, y=y) == g(ξ, y=y)
            @test sf(x) == f(x)
            @test sg(ξ, y=y) == g(ξ, y=y)
        end
        @test callcount[1] == 3N_CALL_LOOPS
        @test callcount[2] == 3N_CALL_LOOPS
    end
end


@testset "Macros1" begin
    callcount = [0, 0]
    f(x::AbstractVector{<:Number}) = (callcount[1] += 1; x⋅x - 1)
    g(x::Number; y::String) = (callcount[2] += 1; x - length(y))

    for i ∈ 1:N_CALL_LOOPS
        x = rand(Float64, rand(64:256))
        ξ = rand(Float64)
        y = randstring(rand(0:31))
        @mem f(x)
        @test @scribeof(f)(x) == f(x)
        @mem g(ξ, y=y)
        @test @scribeof(g)(ξ, y=y) == g(ξ, y=y)
    end
    @test callcount[1] == 2N_CALL_LOOPS
    @test callcount[2] == 2N_CALL_LOOPS
end


@testset "Macros2" begin
    callcount = [0, 0]
    @anamnesis f1(x::AbstractVector{<:Number}) = (callcount[1] += 1; x⋅x - 1)
    @anamnesis g1(x::Number; y::String)::String = (callcount[2] += 1; string(x, y))

    for i ∈ 1:N_CALL_LOOPS
        x = rand(Float64, rand(64:256))
        ξ = rand(Float64)
        y = randstring(rand(0:31))
        @test f1(x) == @rawfunc(f1)(x)
        @test f1(x) == @rawfunc(f1)(x)
        @test g1(ξ, y=y) == @rawfunc(g1)(ξ, y=y)
        @test @inferred g1(ξ, y=y) == @rawfunc(g1)(ξ, y=y)
    end
    @test callcount[1] == 3N_CALL_LOOPS
    @test callcount[2] == 3N_CALL_LOOPS
end


@testset "Macros3" begin
    callcount = [0, 0, 0]
    f2(x::AbstractVector{<:Number}) = (callcount[1] += 1; x⋅x - 1)
    g2(x::Number; y::String) = (callcount[2] += 1; string(x, y))
    h2(x) = (callcount[3] += 1; x)
    @anamnesis begin
        x = [1,2]
        f2(x) + h2(3)
        z = [f2(x), h2(3)]
        string(g2(1, y="fire"), g2(2, y="walk"), h2("with"), h2("me"))
        A = [h2("with") g2(1,y="fire")
             g2(2,y="walk") h2("me")]
    end f2 g2
    @test callcount[1] == 1
    @test callcount[2] == 2
    @test callcount[3] == 6
end

