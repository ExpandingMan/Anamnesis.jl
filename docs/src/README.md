# Anamnesis.jl
> Anamnesis [an-am-**nee**-sis]:
>   1. the recollection or rememberance of the past
>   2. recollection of the ideas which the soul had known in a previous existence, especially by means of reasoning

A package for doing fancy [memoizing](https://en.wikipedia.org/wiki/Memoization) of computationally expensive functions in Julia.  Some features which
distinguish this package from standard implementations of "memoize" are

- Optionally storing function results on the local file system with a minimum of deserialization overhead.  This allows memoization of functions between
    completely separate program instances.
- Inference of floating point arguments.  Floating point values which are intended to be equal may differ slightly due to machine error.  This package will
    attempt to infer if one of the floating point arguments given is very close to one that has been seen previously.
- Hashing of large arguments.  Sometimes the arguments themselves are quite large, and it is undesirable to store them redundantly (especailly in the case
    when the memoization is being done to the local file system).  Anamnesis creates hashes of large arguments so that they do not need to be stored, at the
    expense of hashing time and a small possibility of collisions.
- Unobtrusive design.  The package is built primarily around the macro `@anamnesis` which memoizes functions seen in code while requiring a bare minimal
    change to the existing code.

The primary envisioned use cases of Anamnesis are 

- Development of scientific programs.  Often in scientific programing a program is created to do a complicated calculation, return a result and exit.  In
    the course of developing such a program it is common to change code and re-run the programming frequently in order to experiment and get the desired result.
    Sometimes this involves a great deal of re-calculation of intermediate results in the sections of the program that are *not* changed.
- Development of programs with expensive database queries.  Some programming requires database queries which are expensive, and may take a long time to run.
    Alternatively, one can make these queries ahead of time and store the results.  Anamnesis makes this process much easier by obviating the need to write any
    specialized code for doing this.


## The `@anamnesis` Macro
The primary functionality of this package is accessible through the `@anamnesis` macro.  This macro will take function calls (possibly involved in assignments)
and wrap them in an object used for storing and later retrieving there results.  For example, one can do
```julia
@anamnesis y = f(x, y)
```
This will create a wrapper for `f` (which we call a "scribe", see the section on scribe objects) which memoizes `f`.  Whenever `f` is called with a new
argument, it will be evaluated an the results will be stored.  If the argument has been seen before, the results will be retrieved without calling `f` again.
Further calls to `f` using this wrapper can be made using `@anamnesis` again.  For example, after having run the above line if we run `@anamnesis f(x,y)` again,
`f` will not be evaluated, and the result returned will be the one computed in the line above.  Note that one can call `@anamnesis` on function call or
assignment expressions, the only difference being that for assignments, in addition to performing memoization tasks it will make the assignment as normal.

### Using the Local File System
Using the `@anamnesis` macro as written above will employ a more-or-less standard implementation of memoization, in which function values are stored only in
memory (RAM).  It is frequently useful to retain function values even after a program has been exited completely and it's memory page has been deleted.  For
these cases, we allow memoization to the local file system.  For example, one can do
```julia
@anamnesis "storage_directory" z = f(x, y)
```
This will create the directory `"storage_directory"` (if it doesn't already exist) in which function evaluation results will be stored.  The results will *also*
be stored locally until they are explicitly deleted, so the user only has to worry about deserialization overhead when the results don't exist in the programs
memory page at all.  Once `@anamnesis` is called on a function with a directory name, it will store every new evaluation in the directory.  For example, after
the above line is called `@anamnesis f(x, 2y)` will store the result to the local file system even though a directory name was not given again.

If `@anamnesis` has been called with a directory argument and that directory already exists, `@anamnesis` will load function evaluation results from the files
stored in that directory.  So, in the example above, if one now exits the program completely, and creates a new program with the line `@anamnesis f(x,y)` with
the same values of `x` and `y`, the results of previous function calls will be loaded from the file system even though the calls appear in an entirely separate
program.

***WARNING*** Anamnesis identifies functions purely by their name (*TODO* it's possible that in a future update we may also have it identify functions by their
argument types).  This is because there is no reliable way to identify functions in separate programs.  It is therefore possible to spoof Anamnesis into
returning bogus function values if one re-uses a name.  For the most part, it should be easy for the user to watch out for this problem, but one should take
care as Anamnesis also doesn't know about scope (except insofar as the scope the module instance is contained in).

***TODO*** Create functionality for `@anamnesis` on entire blocks of code.


## The "Scribe" Objects
We refer to the memoization wrappers used by Anamnesis as "scribe" objects.  At present there are two types of "scribes" `VolatileScribe` and
`NonVolatileScribe`.  `VolatileScribe` only saves function evaluations to memory while `VolatileScribe` saves them to the local file system.  Under many
circumstances the user will probably just want to use the `@anamnesis` macro so that the scribe objects are hidden (though they can still be accessed through
`Anamnesis.ScribeBox` see below).  In other cases the user may want more convenient access to the wrapper objects themselves.  This can be done by using the
`@scribe` macro.  To create a scribe wrapper for a function `f` one should simply call `@scribe(f)`.  If one wants the scribe to store function evaluations in
the local file system as well one should do `@scribe(dir, f)` where `dir` is the directory the function evaluations are stored in.  This will return the scribe
wrapper.  For example
```julia
f(a, ϕ) = a*e^(im*ϕ)
fs = @scribe(f)  # create a scribe wrapper for `f`
fs(1.0, π)  # memoizes for 1.0, π
z = @anamnesis f(1.0, π)  # this does **not** evaluate, `@anamnesis` knows about the scribe
```
Alternatively one can use the `@scribe` macro to access a scribe wrapper that has already been created through use of `@anamnesis`
```julia
@anamnesis z = f(1.0, π)
fs = @scribe(f)
fs(1.0, π)  # does **not** require evaluation
```
It works the same way with `NonVolatileScribe`, one simply has to pass a directory.  Note that the directory name only has to be passed once.  Once that has
happened, Anamnesis knows that the wrapper for `f` needs to store to the file system.







## API Docs
```@autodocs
Modules = [Anamnesis]
Private = false
```

