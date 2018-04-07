


macro localmem(expr::Expr)
    @capture(expr, f_(args__))
    sname = scribename(f)
    esc(quote
        if !@isdefined($sname)
            $sname = Anamnesis.Scribe($f)
        end
        $sname($(args...))
    end)
end


macro mem(expr::Expr)
    @capture(expr, f_(args__))
    sname = scribename(f)
    esc(quote
        if !@isdefined($sname)
            global const $sname = Anamnesis.Scribe($f)
        end
        $sname($(args...))
    end)
end


macro anamnesis(expr::Expr, funcs::Symbol...)
    expr = postwalk(expr) do ex
        if @capture(ex, f_(args__))

        else
            ex
        end
    end
end
