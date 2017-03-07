
function _anamnesis_getsymbols_call(expr::Expr)
    f = expr.args[1]
    args_ = [a for a ∈ expr.args[2:end] if !isa(a, Expr)]
    kwargs_ = [tuple(a.args...) for a ∈ expr.args[2:end] if isa(a, Expr) && a.head == :kw]
    args = Expr(:tuple, args_...)
    kwargs = Expr(:tuple, kwargs_...)
    nothing, f, args, kwargs
end

function _anamnesis_getsymbols_assignment(expr::Expr)
    val = expr.args[1]    
    if expr.args[2].head ≠ :call
        throw(ArgumentError("@anamnesis argument must contain a function call."))
    end
    _val, f, args, kwargs = _anamnesis_getsymbols_call(expr.args[2])
    val, f, args, kwargs
end

function _anamnesis_getsymbols_(expr::Expr)
    if expr.head == :(=)
        return _anamnesis_getsymbols_assignment(expr)
    elseif expr.head == :call
        return _anamnesis_getsymbols_call(expr)
    end
end

# TODO make work for multiple assignments within a block
function _anamnesis_getsymbols(expr::Expr)
    if expr.head ∈ [:(=), :call]
        return _anamnesis_getsymbols_(expr)
    elseif expr.head == :block
        for arg ∈ expr.args
            if arg.head ∈ [:(=), :call]
                return _anamnesis_getsymbols_(arg)
            end
        end
    end
    throw(ArgumentError("@anamnesis argument must contain an assignment."))
end


macro anamnesis(refresh::Bool, dir, expr)
    val, f, args, kwargs = _anamnesis_getsymbols(expr)
    fname = Expr(:quote, f)
    
    if f ∉ keys(ScribeBox)
        retrieveexpr = quote
            if length($dir) > 0
                Anamnesis.ScribeBox[$fname] = Anamnesis.scribe($f, $fname, $dir)
            else
                Anamnesis.ScribeBox[$fname] = Anamnesis.scribe($f, $fname)
            end
        end
    else  # in this case we check if we need to promote to NonVolatileScribe
        retrieveexpr = quote
            if length($dir) > 0
                Anamnesis.ScribeBox[$fname] = 
                    Anamnesis.NonVolatileScribe(Anamnesis.ScribeBox[$fname], $dir)
            end
        end
    end

    callsymb = refresh ? Symbol(:refresh!) : Symbol(:execute!)

    if args == :(())
        callexpr = :(Anamnesis.$callsymb(Anamnesis.ScribeBox[$fname]; $kwargs...))
    else
        callexpr = :(Anamnesis.$callsymb(Anamnesis.ScribeBox[$fname], $args...; $kwargs...))
    end

    if val ≠ nothing
        callexpr = :($val = $callexpr)
    end

    esc(quote
        $retrieveexpr
        $callexpr
    end)
end

macro anamnesis(dir, expr)
    esc(:(@anamnesis false $dir $expr))
end

macro anamnesis!(dir, expr)
    esc(:(@anamnesis true $dir $expr))
end

macro anamnesis(expr)
    esc(:(@anamnesis false "" $expr))
end

macro anamnesis!(expr)
    esc(:(@anamnesis true "" $expr))
end

export @anamnesis, @anamnesis!


