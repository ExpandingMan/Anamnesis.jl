module Anamnesis
# TODO make DataFrames dependency conditional and remove DatasToolbox dependency
using DatasToolbox
using DataFrames

# TODO implement kwargs
# TODO have separate metadata for each function so that multiple functions can share a dir



const METADATE_FILENAME = "metadata.jbin"
const FILENAME_RANDSTRING_LENGTH = 12
ARGHASH_FLOAT_DIGITS = 12


abstract AbstractScribe

# these are scribes that are getting stored for macros
ScribeBox = Dict{Symbol,AbstractScribe}()


#=================================================================================
    Metadata Dictionary Format

The metadata dictionary has keys which are Vector{Any}s with the function name
followed by the hashed arguments.
=================================================================================#
metadataFileName(dir::String) = joinpath(dir, METADATE_FILENAME)
loadMetadata_raw(dir::String) = deserialize(metadataFileName(dir))


"""
    loadMetadata(dir)

Load a metadata dictionary (the kind used by scribes) found in the directory `dir`.
If a file doesn't exist in the directory with the standard metadat filename 
(`Anamnesis.METADATE_FILENAME`), an empty `Dict` will be returned instead.
"""
function loadMetadata(dir::String)
    filename = metadataFileName(dir)
    if isfile(filename)
        return loadMetadata_raw(dir)
    end
    Dict()  # if file doesn't exist, return empty Dict
end


"""
    saveMetadata(dir, meta)

Saves the `Dict` `meta` to the directory `dir` in a file with the standard metadata file name
(`Anamnesis.METADATE_FILENAME`).
"""
function saveMetadata(dir::String, meta::Dict)
    serialize(joinpath(dir, METADATE_FILENAME), meta)
end


"""
    metadata(scr)

Gets the `Dict` from the `AbstractScribe` `scr` which would be stored as metadata.
Essentially, this is a dict with all the data that would be stored in the `scr.vals` dict
but without the actual function evaluation results.
"""
function metadata(s::AbstractScribe)
    meta = copy(s.vals)
    for (k, v) ∈ meta
        nv = Dict{Any,Any}(k_=>v_ for (k_, v_) ∈ v if k_ ≠ :val)  # store all but value
        meta[k] = nv
    end
    meta
end

"""
    loadfile(filename)

Loads a file using the appropriate deserialization method for the file extension.
"""
function loadfile(filename::String)
    ext = convert(String, split(filename, '.')[end])
    if ext == ".feather"
        return featherRead(filename)
    end
    deserialize(filename)
end


"""
    mergeValueDicts!(into, from)

Merges dicts of the type that are stored in the `vals` field of `AbstractScribe` objects,
storing the result in `into`.  If one of the inner dicts have keys that are present in
both `into` and `from`, the value from `from` takes precedence.
"""
function mergeValueDicts!(into::Dict, from::Dict)
    for (k, v) ∈ from
        if k ∈ keys(into)
            # keeps values from v where there are conflicts
            into[k] = merge(into[k], v)
        else
            into[k] = v
        end
    end
    into
end


#====================================================================================
    Scribes

These are the objects that store a function along with a means of memorizing it.

All data about function evaluations are stored in the `vals` field, which is a 
`Dict` of `Dict`s.  The reason for the nested dicts as opposed to multiple dicts
is to make these more extensible.
====================================================================================#
"""
    VolatileScribe(f, name)

This is essentially a wrapper for the function `f` (which is given the `Symbol` name `name`)
which "memoizes" the function.  The "volatile" variant of the scribes holds function 
evaluations in the program memory, so this version is close to a straight-forward `memoize`
implementation.  In addition, it has some methods for dealing with argument accuracy and size,
as well as some methods for easily converting into `NonVolatileScribe`.

Note that all scribe objects identify functions purely by their names.
"""
type VolatileScribe <: AbstractScribe
    f::Function
    vals::Dict
    name::Symbol

    VolatileScribe(f::Function, name::Symbol) = new(f, Dict(), name)
end
export VolatileScribe


# this is a separate type mainly for multiple dispatch reasons
"""
    NonVolatileScribe(f, name, dir)

This is essentially a wrapper for the function `f` (which is given the `Symbol` name `name`)
which "memoizes" the function.  The "non-volatile" variant of the scribes hold the function
evaluations on the local file system so that function evaluations can be stored between
separate instances of a program.  Additionally, it has some methods for dealing with argument
accuracy and size.

`NonVolatileScribe` uses "lazy" deserialization of files.  That is, any evaluations it has
seen in a program instance are stored in memory, only when a new evaluation is made for which
the scribe knows it has the result in a file, but lacks the result in local memory will it
deserialize anything.  Furthermore, function evaluations are saved in completely separate 
files so that deserialization time for a single function call doesn't depend on how many
results are stored.

Note that all scribe objects identify functions purely by their names.

## "Promoting" `VolatileScribe`
One can also do `VolatileScribe(s, dir)` where `s` is a `VolatileScribe`.  When this is done,
the scribe will determine if the directory `dir` exists.  If it does, it will load all 
function evaluations from there and merge those with any that it has already evaluated
in the course of the program, which will also be stored to files in `dir`.  If `dir` does
not exist, it will be created along with any evaluations that the scribe holds.
"""
type NonVolatileScribe <: AbstractScribe
    f::Function
    vals::Dict
    name::Symbol
    dir::String

    function NonVolatileScribe(f::Function, name::Symbol, dir::String)
        !isdir(dir) && mkdir(dir)
        new(f, loadMetadata(dir), name, dir)
    end
end
export NonVolatileScribe


# demotion to VolatileScribe retains `:file` entires; no reason to delete them
function VolatileScribe(s::NonVolatileScribe, dir::String)
    o = VolatileScribe(s.f, s.name)
    o.vals = s.vals
    o
end


# this is a promotion from a VolatileScribe to a NonVolatileScribe
function NonVolatileScribe(s::VolatileScribe, dir::String)
    o = NonVolatileScribe(s.f, s.name, dir)
    o.vals = copy(s.vals)
    meta = loadMetadata(dir)  # and load and merge the metadata
    mergeValueDicts!(o.vals, meta)
    # now we need to make files for everything that's missing
    for (k, v) ∈ o.vals
        if (:val ∈ keys(v)) && (:file ∉ keys(v))
            y = v[:val]
            _save_eval!(o, v, k, y)
        end
    end
    o
end

# TODO implement this inside anamnesis macro
function NonVolatileScribe(s::NonVolatileScribe, dir::String)
    if s.dir == dir
        return s
    end
    if isdir(s.dir)
        throw(ArgumentError("Attempting to save to extant directory."))
    end
    old_dir = s.dir
    s.dir = dir
    mkdir(s.dir)
    saveMetadata(s.dir, metadata(s))
    for (k, v) ∈ s.vals
        # if the file already existed, just copy it without deserializing
        if (:file ∈ keys(v))
            cp(joinpath(old_dir,v[:file]), joinpath(s.dir,v[:file]))   
        else
            y = v[:val]
            _save_eval!(s, v, k, y)
        end
    end
end



function _generate_filename_raw{T}(s::AbstractScribe, ::Type{T})
    filename = string(s.name, "_", randstring(FILENAME_RANDSTRING_LENGTH), ".jbin")
end
function _generate_filename_raw(s::AbstractScribe, ::Type{DataFrame})
    filename = string(s.name, "_", randstring(FILENAME_RANDSTRING_LENGTH), ".feather")
end

# this is a bad way of doing this but shouldn't matter
function _generate_filename{T}(s::AbstractScribe, ::Type{T})
    filename = _generate_filename_raw(s, T)
    while isfile(joinpath(s.dir, filename))
        filename = _generate_filename_raw(s, T)
    end
    filename
end


# this is is the implementation of "memoize"
function (s::VolatileScribe)(args...)
    key_args = hashArgs(args)
    dict = get(s.vals, key_args, Dict())
    if (:val ∈ keys(dict))
        y = dict[:val]
    else
        y = s.f(args...)
        dict[:val] = y
        s.vals[key_args] = dict
    end
    y
end


_save_eval(filename::String, y) = serialize(filename, y)
_save_eval(filename::String, y::DataFrame) = featherWrite(filename, y)

function _save_eval!(s::NonVolatileScribe, dict::Dict, key_args, y)
    filename = _generate_filename(s, typeof(y))
    dict[:val] = y
    dict[:file] = filename
    s.vals[key_args] = dict
    meta = metadata(s)  # TODO clean this shit up! shouldn't run all the time
    saveMetadata(s.dir, meta)  # for now we save metadata every time.  ugh
    _save_eval(joinpath(s.dir, filename), y)
end


# this is memoize with storing on disk
function (s::NonVolatileScribe)(args...)
    key_args = hashArgs(args)
    dict = get(s.vals, key_args, Dict())
    if (:val ∈ keys(dict))
        y = dict[:val]
    elseif (:file ∈ keys(dict))
        y = loadfile(joinpath(s.dir, dict[:file]))
        dict[:val] = y
        s.vals[key_args] = dict
    else
        y = s.f(args...)
        _save_eval!(s, dict, key_args, y)
    end
    y
end


"""
    execute!(scr, args...)

This is an alias for calling the scribe object.  It is useful to have this form for writing
some of the macro code.
"""
execute!(s::AbstractScribe, args...) = s(args...)
export execute!


"""
    forget!(scr, args...)

Delete the records of a particular function call saved by the scribe object `scr`.  If these
are stored in the files system, the appropriate files will be deleted as well.

Note that this will *not* throw an error if the entry for the arguments provided do not
exist.
"""
function forget!(s::AbstractScribe, args...)
    key_args = hashArgs(args) 
    y = get(s.vals[key_args], :val, nothing)
    delete!(s.vals, key_args)
    y
end

function forget!(s::NonVolatileScribe, args...)
    key_args = hashArgs(args)
    if (:file ∈ keys(s.vals[key_args]))
        rm(joinpath(s.dir, s.vals[key_args][:file]))  # want an error if missing
    end
    delete!(s.vals, key_args)
end
export forget!


"""
    purge(scr)
    purge(dir)

Delete a directory and its contents.  If an `AbstractScribe` argument is provided,
the directory will be deleted, and a non-volatile scribe object will be returned.  
"""
purge(dir::String) = rm(dir, force=true, recursive=true)
function purge(scr::NonVolatileScribe)
    purge(scr.dir)
    NonVolatileScribe(scr)
end
export purge


"""
    refresh!(scr, args...)

Re-calculate the value of the function associated with the scribe object `scr`, storing the
new value in the ways it would normally be stored after a function call with the type of
scribe object given.
"""
function refresh!(s::AbstractScribe, args...)
    forget!(s, args...)
    s(args...)
end
export refresh!


"""
    arghash(a)

Create a hash from a function argument which is appropriate for using as a key when 
memorizing the function.  By default, the method `hash(a)` will be called.

`Number`s will be stored as is, unless they are `AbstractFloat` which will be rounded to
the number of digits given by `Anamnesis.ARGHASH_FLOAT_DIGITS`.

**TODO** we still don't have a way of dealing with hash collisions.  This shouldn't even
in general be possible without actually storing the exact arguments.  Note that the 
collisions caused by rounding floats are intentional.
"""
arghash(a) = hash(a)
arghash(a::Number) = a
arghash(a::AbstractFloat) = round(a, ARGHASH_FLOAT_DIGITS)


"""
    hashArgs(args)

Create a vector holding the hash values for the supplied arguments (either a tuple or vector).
See the documentation for `arghash` for information on how the arguments are hashed.
"""
function hashArgs(args::Union{Tuple,Vector})
    key_args = Vector{Any}(length(args))
    for (i, arg) ∈ enumerate(args)
        key_args[i] = arghash(arg)
    end
    key_args
end


# right now this is just an alias for FunctionScribe, will add to later
"""
    scribe(f, name)
    scribe(f, name, dir)

Create a scribe object for function `f` of name `name`.  This will be a `NonVolatileScribe` 
if a directory is supplied or a `VolatileScribe` otherwise.

Note that these functions do not store the functions in the Anamnesis module.

Under most circumstances it is recomended that users use the `@scribe` macro instead.
"""
scribe(f::Function, name::Symbol) = VolatileScribe(f, name)
scribe(f::Function, name::Symbol, dir::String) = NonVolatileScribe(f, name, dir)
export scribe


"""
    @scribe(f)
    @scribe(dir, f)

Create a "scribe" object from the function `f`.  The "scribe" object is essentially a wrapper
that when called will evaluate `f` while memorizing the results, either in memory or, in the
case where a directory `dir` is provided, on the local file system.

Additionally, the "scribe" object will be stored in the Anamnesis module in a dictionary
called `ScribeBox` the keys of which are the function name.  Calling `@scribe` when a 
function with the name of `f` already exists in `ScribeBox` will retrieve that scribe 
instead of creating a new one.

Note that functions are identified entirely by name, so this macro will confuse distinct
functions which are given the same name, regardless of scope.
"""
macro scribe(f)
    fname = Expr(:quote, f)
    if f ∉ keys(ScribeBox)
        o = :(Anamnesis.ScribeBox[$fname] = Anamnesis.scribe($f, $fname))
    else
        o = :(Anamnesis.ScribeBox[$fname])
    end
    esc(o)
end

macro scribe(dir, f)
    fname = Expr(:quote, f)
    if f ∉ keys(ScribeBox)
        o = quote
            @assert typeof($dir) <: AbstractString "Directory must be a string."
            Anamnesis.ScribeBox[$fname] = Anamnesis.scribe($f, $fname, $dir)
        end
    else
        # check if existing needs to be promoted
        o = quote
            @assert typeof($dir) <: AbstractString "Directory must be a string."
            if !isa(Anamnesis.ScribeBox[$fname], NonVolatileScribe)
                Anamnesis.ScribeBox[$fname] = 
                    NonVolatileScribe(Anamnesis.ScribeBox[$fname], $dir)
            end
            Anamnesis.ScribeBox[$fname]
        end
    end
    esc(o)
end
export @scribe



#=========================================================================================
  <@anamnesis (and related)>
=========================================================================================#
function _anamnesis_getsymbols_call(expr::Expr)
    f = expr.args[1]
    args = Expr(:tuple, expr.args[2:end]...)
    nothing, f, args
end

function _anamnesis_getsymbols_assignment(expr::Expr)
    val = expr.args[1]    
    if expr.args[2].head ≠ :call
        throw(ArgumentError("@anamnesis argument must contain a function call."))
    end
    _val, f, args = _anamnesis_getsymbols_call(expr.args[2])
    val, f, args
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
    val, f, args = _anamnesis_getsymbols(expr)
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

    if val == nothing
        callexpr = :(Anamnesis.$callsymb(Anamnesis.ScribeBox[$fname], $args...))
    else
        callexpr = :($val = Anamnesis.$callsymb(Anamnesis.ScribeBox[$fname], $args...))
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


end
