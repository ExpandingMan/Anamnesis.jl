

"""
    clearScribeBox!()

Resets the `ScribeBox`, which holds references to scribes created with `@scribe` or 
`@anamnesis`.
"""
function clearScribeBox!()
    global ScribeBox = Dict{Symbol,AbstractScribe}()
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
        new(f, loadMetadata(dir, name), name, dir)
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
    meta = loadMetadata(o)
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


"""
    metadataFileName(scr)

Gets the full metadata file name (with the full path) for the `NonVolatileScribe` `scr`.
"""
metadataFileName(s::NonVolatileScribe) = metadataFileName(s.dir, s.name)


"""
    saveMetadata(scr)

Save metadata for the `NonVolatileScribe` `scr`.
"""
function saveMetadata(s::NonVolatileScribe)
    meta = metadata(s)
    saveMetadata(s.dir, s.name, meta)
end


"""
    loadMetadata(scr)

Load the metadata for the `NonVolatileScribe` `scr`.
"""
loadMetadata(s::NonVolatileScribe) = loadMetadata(s.dir, s.name)


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
function (s::VolatileScribe)(args...; kwargs...)
    key_args = hashArgs(args, kwargs)
    dict = get(s.vals, key_args, Dict())
    if (:val ∈ keys(dict))
        y = dict[:val]
    else
        y = s.f(args...; kwargs...)
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
    saveMetadata(s)  # TODO clean this shit up!  shouldn't run all the time
    _save_eval(joinpath(s.dir, filename), y)
end


# this is memoize with storing on disk
function (s::NonVolatileScribe)(args...; kwargs...)
    key_args = hashArgs(args, kwargs)
    dict = get(s.vals, key_args, Dict())
    if (:val ∈ keys(dict))
        y = dict[:val]
    elseif (:file ∈ keys(dict))
        y = loadfile(joinpath(s.dir, dict[:file]))
        dict[:val] = y
        s.vals[key_args] = dict
    else
        y = s.f(args...; kwargs...)
        _save_eval!(s, dict, key_args, y)
    end
    y
end


"""
    execute!(scr, args...)

This is an alias for calling the scribe object.  It is useful to have this form for writing
some of the macro code.
"""
execute!(s::AbstractScribe, args...; kwargs...) = s(args...; kwargs...)
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
arghash(a::Symbol) = a
# tuples resulting from keyword arguments
arghash(a::Tuple) = tuple([arghash(a_) for a_ ∈ a]...)


"""
    hashArgs(args[, kwargs])

Create a vector holding the hash values for the supplied arguments (either a tuple or vector).
See the documentation for `arghash` for information on how the arguments are hashed.

If keywords arguments are provided (as an array of tuples), they will simply be concatenated
onto the keys generated for the other arguments.
"""
function hashArgs(args::Union{Tuple,Vector})
    key_args = Vector{Any}(length(args))
    for (i, arg) ∈ enumerate(args)
        key_args[i] = arghash(arg)
    end
    key_args
end

hashArgs(args::Union{Tuple,Vector}, kwargs::Vector) = vcat(hashArgs(args), hashArgs(kwargs))


# right now this is just an alias for FunctionScribe, will add to later
"""
    scribe(f, name)
    scribe(f, name, dir)

Create a scribe object for function `f` of name `name`.  This will be a `NonVolatileScribe` 
if a directory is supplied or a `VolatileScribe` otherwise.  (If an empty string is supplied
for `dir`, this will return a `NonVolatileScribe`.)

Note that these functions do not store the functions in the Anamnesis module.

Under most circumstances it is recomended that users use the `@scribe` macro instead.
"""
scribe(f::Function, name::Symbol) = VolatileScribe(f, name)
function scribe(f::Function, name::Symbol, dir::String)
    if length(dir) > 0
        return NonVolatileScribe(f, name, dir)
    end
    VolatileScribe(f, name)
end
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

