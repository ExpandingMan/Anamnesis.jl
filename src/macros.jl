

macro localscribe(f::Symbol, dict=:(IdDict()))
    sname = scribename(f)
    esc(quote
        !@isdefined($sname) && ($sname = Anamnesis.Scribe($f, $dict))
        $sname
    end)
end

macro scribe(f::Symbol, dict=:(IdDict()))
    sname = scribename(f)
    esc(quote
        !@isdefined($sname) && (global $sname = Anamnesis.Scribe($f, $dict))
        $sname
    end)
end


macro localmem(expr::Expr)
    @capture(expr, f_(args__))
    esc(:(@localscribe($f)($(args...))))
end

macro mem(expr::Expr)
    @capture(expr, f_(args__))
    esc(:(@scribe($f)($(args...))))
end


argname(x)::Symbol = splitarg(x)[1]

function _translate_kwarg(ex::Expr)
    arg = argname(ex)
    Expr(:kw, arg, arg)
end


macro anamnesis(expr::Expr)
    origdef = splitdef(expr)
    fname = origdef[:name]

    rawfuncdef = copy(origdef)
    rawname = rawfuncname(fname)
    rawfuncdef[:name] = rawname

    scrname = scribename(rawname)

    funcdef = copy(origdef)
    kwargs = _translate_kwarg.(funcdef[:kwargs])
    funcdef[:body] = quote
        $scrname($(map(argname, funcdef[:args])...); $(kwargs...))
    end

    esc(quote
        $(MacroTools.combinedef(rawfuncdef))
        $scrname = Anamnesis.Scribe($rawname)
        $(MacroTools.combinedef(funcdef))
    end)
end


macro anamnesis(expr::Expr, funcs::Symbol...)
    expr = MacroTools.postwalk(expr) do ex
        if @capture(ex, f_(args__)) && (f ∈ funcs)
            :(@mem $ex)
        else
            ex
        end
    end
    esc(expr)
end
