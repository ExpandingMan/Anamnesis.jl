

scribename(fname::Symbol) = Symbol(string("##", fname, "__scribe"))

macro scribename(fname::Symbol)
    fname = Expr(:quote, scribename(fname))
    esc(:($fname))
end

macro scribename(fcall::Expr)
    @capture(fcall, fname_(args__))
    fname = Expr(:quote, scribename(fname))
    esc(:($fname))
end

macro scribeof(func::Symbol)
    sname = scribename(func)
    esc(:($sname))
end

macro scribeof(fcall::Expr)
    @capture(fcall, fname_(args__))
    sname = scribename(fname)
    esc(:($sname))
end
