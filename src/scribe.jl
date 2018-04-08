
abstract type AbstractScribe{F<:Function} end
abstract type ReturnSpecifier end

struct Unseen <: ReturnSpecifier end


struct Scribe{F<:Function,D<:AbstractDict} <: AbstractScribe{F}
    f::F
    cache::D
end

Scribe(f::Function) = Scribe(f, IdDict{Any,Any}())

# functions which can be overloaded by user for better type stability
returntype(f::Function, argtypes) = return_type(f, argtypes)
returntype(f::Function, argtypes, kwargtypes) = Any

returntype(s::AbstractScribe, argtypes) = returntype(s.f, argtypes)
returntype(s::AbstractScribe, argtypes, kwargtypes) = returntype(s.f, argtypes, kwargtypes)

Base.getindex(s::AbstractScribe, args) = get(s.cache, args, Unseen)
Base.setindex!(s::AbstractScribe, val, args) = setindex!(s.cache, val, args)

scry(s::AbstractScribe, ::Type{Unseen}, args) = (s[args] = s.f(args...))
scry(s::AbstractScribe, ret, args) = ret::returntype(s, typeof(args))

scry(s::AbstractScribe, ::Type{Unseen}, args, kwargs) = (s[(args,kwargs)] = s.f(args...; kwargs...))
scry(s::AbstractScribe, ret, args, kwargs) = ret::returntype(s, typeof(args), typeof(kwargs))


call(s::AbstractScribe, args...) = scry(s, s[args], args)

function (s::Scribe)(args...; kwargs...)
    isempty(kwargs) ? scry(s, s[args], args) : scry(s, s[(args,kwargs)], args, kwargs)
end
