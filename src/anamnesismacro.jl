
function _anamnesis_getsymbols_call(expr::Expr)
    f = expr.args[1]
    kwargs_ = [a for a ∈ expr.args[2:end] if isa(a, Expr) && a.head == :kw]
    args_ = [a for a ∈ expr.args[2:end] if a ∉ kwargs_]
    kwargs_ = [tuple(a.args...) for a ∈ kwargs_]
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

function _anamnesis_getsymbols_line(expr::Expr)
    if expr.head == :(=)
        return _anamnesis_getsymbols_assignment(expr)
    elseif expr.head == :call
        return _anamnesis_getsymbols_call(expr)
    else
        throw(ArgumentError("@anamnesis argument must contain a function call."))
    end
end

function _check_ScribeBox(f::Function, fname::Symbol, dir::String)
    if fname ∈ keys(ScribeBox)
        if length(dir) > 0 && (!isa(ScribeBox[fname], NonVolatileScribe) ||
                               ScribeBox[fname].dir ≠ dir)
            ScribeBox[fname] = NonVolatileScribe(ScribeBox[fname], dir)
        end
    else
        ScribeBox[fname] = scribe(f, fname, dir)
    end
end

function _anamnesis_line(refresh::Bool, dir::Union{Symbol,String}, expr::Expr)
    val, f, args, kwargs = _anamnesis_getsymbols_line(expr)
    fname = Expr(:quote, f)
    
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
        Anamnesis._check_ScribeBox($f, $fname, $dir)
        $callexpr
    end)
end

# this macro only goes one tier down, use _anamnesis_block_funcs to go deeper
function _anamnesis_block(refresh::Bool, dir::Union{Symbol,String}, expr::Expr)
    for (i, arg) ∈ enumerate(expr.args)
        if isa(arg, Expr)
            if arg.head ∈ [:(=), :call, :block]
                expr.args[i] = :(@anamnesis $refresh $dir $arg)
            elseif arg.head == :macrocall
                if arg.args[1] == Symbol("@forget")
                    expr.args[i] = arg.args[2]  # anything trailing gets deleted
                end
            end
        end
    end
    esc(expr)
end

# this very deliberately does nothing
function _anamnesis_block_func!{N}(refresh::Bool, dir::Union{Symbol,String}, expr,
                                   funcs::Tuple{Vararg{Symbol,N}})
    expr
end

function _anamnesis_block_func!{N}(refresh::Bool, dir::Union{Symbol,String}, expr::Expr,
                                   funcs::Tuple{Vararg{Symbol,N}})
    if expr.head == :call && expr.args[1] ∈ funcs
        expr = :(@anamnesis $refresh $dir $expr)
    else
        for i ∈ 1:length(expr.args)
            expr.args[i] = _anamnesis_block_func!(refresh, dir, expr.args[i], funcs)
        end
    end
    expr
end

"""
    @anamnesis f(a,b,c,...)
    @anamnesis dir f(a,b,c,...)
    @anamnesis y = f(a,b,c,...)
    @anamnesis dir y = f(a,b,c,...)

Memoizes a function call.  It's also possible to memoize all calls of particular functions
in an entire block of code.

This is the main functionality of the Anamnesis package.  See README for example uses.
"""
macro anamnesis(refresh::Bool, dir::Union{String,Symbol}, expr::Expr)
    if expr.head ∈ [:(=), :call]
        return _anamnesis_line(refresh, dir, expr)
    elseif expr.head ∈ [:block, :function]
        return _anamnesis_block(refresh, dir, expr)
    end
end

macro anamnesis(refresh::Bool, dir::Union{String,Symbol}, expr::Expr, funcs::Symbol...)
    esc(_anamnesis_block_func!(refresh, dir, expr, funcs)) 
end

macro anamnesis(dir::Union{String,Symbol}, expr::Expr)
    esc(:(@anamnesis false $dir $expr))
end

macro anamnesis(dir::Union{String,Symbol}, expr::Expr, funcs::Symbol...)
    esc(_anamnesis_block_func!(false, dir, expr, funcs))
end

macro anamnesis!(dir::Union{String,Symbol}, expr::Expr)
    esc(:(@anamnesis true $dir $expr))
end

macro anamnesis!(dir::Union{String,Symbol}, expr::Expr, funcs::Symbol...)
    esc(_anamnesis_block_func!(true, dir, expr, funcs))
end

macro anamnesis(expr::Expr)
    esc(:(@anamnesis false "" $expr))
end

macro anamnesis(expr::Expr, funcs::Symbol...)
    esc(_anamnesis_block_func!(false, "", expr, funcs))
end

macro anamnesis!(expr::Expr)
    esc(:(@anamnesis true "" $expr))
end

macro anamnesis!(expr::Expr, funcs::Symbol...)
    esc(_anamnesis_block_func!(true, "", expr, funcs))
end

export @anamnesis, @anamnesis!


