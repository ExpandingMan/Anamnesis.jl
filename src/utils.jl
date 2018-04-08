

scribename(fname::Symbol) = Symbol(string("##", fname, "__scribe"))

rawfuncname(fname::Symbol) = Symbol(string("##", fname, "__raw"))

macro scribename(fname::Symbol)
    fname = Expr(:quote, scribename(fname))
    esc(:($fname))
end

macro scribeof(func::Symbol)
    sname = scribename(func)
    esc(:($sname))
end

macro rawfunc(func::Symbol)
    fname = rawfuncname(func)
    esc(:($fname))
end

macro scribeofrawfunc(func::Symbol)
    sname = scribename(rawfuncname(func))
    esc(:($sname))
end

macro rawcall(fcall::Expr)
    @capture(fcall, fname_(args__))
    fname = rawfuncname(fname)
    esc(:($fname($(args...))))
end
