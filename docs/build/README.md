
<a id='Anamnesis.jl-1'></a>

# Anamnesis.jl


> Anamnesis [an-am-**nee**-sis]:
>
> 1. the recollection or rememberance of the past
> 2. recollection of the ideas which the soul had known in a previous existence, especially by means of reasoning



A package for doing fancy [memoizing](https://en.wikipedia.org/wiki/Memoization) of computationally expensive functions in Julia.  Some features which distinguish this package from standard implementations of "memoize" are     * Optionally storing function results on the local file system with a minimum of deserialization overhead.  This allows memoization of functions between         completely separate program instances.     * Inference of floating point arguments.  Floating point values which are intended to be equal may differ slightly due to machine error.  This package will         attempt to infer if one of the floating point arguments given is very close to one that has been seen previously.     * Hashing of large arguments.  Sometimes the arguments themselves are quite large, and it is undesirable to store them redundantly (especailly in the case         when the memoization is being done to the local file system).  Anamnesis creates hashes of large arguments so that they do not need to be stored, at the         expense of hashing time and a small possibility of collisions.     * Unobtrusive design.  The package is built primarily around the macro `@anamnesis` which memoizes functions seen in code while requiring a bare minimal         change to the existing code.


The primary envisioned use cases of Anamnesis are      * Development of scientific programs.  Often in scientific programing a program is created to do a complicated calculation, return a result and exit.  In         the course of developing such a program it is common to change code and re-run the programming frequently in order to experiment and get the desired         result.  Sometimes this involves a great deal of re-calculation of intermediate results in the sections of the program that are *not* changed.     * Development of programs with expensive database queries.  Some programming requires database queries which are expensive, and may take a long time to run.         Alternatively, one can make these queries ahead of time and store the results.  Anamnesis makes this process much easier by obviating the need to write         any specialized code for doing this.


<a id='The-@anamnesis-Macro-1'></a>

## The `@anamnesis` Macro


The primary functionality of this package is accessible through the `@anamnesis` macro.  This macro will take function calls (possibly involved in assignments) and wrap them in an object used for storing and later retrieving there results.  For example, one can do


```julia
@anamnesis y = f(x, y)
```


This will create a wrapper for `f` (which we call a "scribe", see the section on scribe objects) which memoizes `f`.  Whenever `f` is called with a new argument, it will be evaluated an the results will be stored.  If the argument has been seen before, the results will be retrieved without calling `f` again. Further calls to `f` using this wrapper can be made using `@anamnesis` again.  For example, after having run the above line if we run `@anamnesis f(x,y)` again, `f` will not be evaluated, and the result returned will be the one computed in the line above.  Note that one can call `@anamnesis` on function call or assignment expressions, the only difference being that for assignments, in addition to performing memoization tasks it will make the assignment as normal.


<a id='Using-the-Local-File-System-1'></a>

### Using the Local File System


Using the `@anamnesis` macro as written above will employ a more-or-less standard implementation of memoization, in which function values are stored only in memory (RAM).  It is frequently useful to retain function values even after a program has been exited completely and it's memory page has been deleted.  For these cases, we allow memoization to the local file system.  For example, one can do


```julia
@anamnesis "storage_directory" z = f(x, y)
```


This will create the directory `"storage_directory"` (if it doesn't already exist) in which function evaluation results will be stored.  The results will *also* be stored locally until they are explicitly deleted, so the user only has to worry about deserialization overhead when the results don't exist in the programs memory page at all.  Once `@anamnesis` is called on a function with a directory name, it will store every new evaluation in the directory.  For example, after the above line is called `@anamnesis f(x, 2y)` will store the result to the local file system even though a directory name was not given again.


If `@anamnesis` has been called with a directory argument and that directory already exists, `@anamnesis` will load function evaluation results from the files stored in that directory.  So, in the example above, if one now exits the program completely, and creates a new program with the line `@anamnesis f(x,y)` with the same values of `x` and `y`, the results of previous function calls will be loaded from the file system even though the calls appear in an entirely separate program.


***WARNING*** Anamnesis identifies functions purely by their name (*TODO* it's possible that in a future update we may also have it identify functions by their argument types).  This is because there is no reliable way to identify functions in separate programs.  It is therefore possible to spoof Anamnesis into returning bogus function values if one re-uses a name.  For the most part, it should be easy for the user to watch out for this problem, but one should take care as Anamnesis also doesn't know about scope (except insofar as the scope the module instance is contained in).


***TODO*** Create functionality for `@anamnesis` on entire blocks of code.


<a id='The-"Scribe"-Objects-1'></a>

## The "Scribe" Objects


We refer to the memoization wrappers used by Anamnesis as "scribe" objects.  At present there are two types of "scribes" `VolatileScribe` and `NonVolatileScribe`.  `VolatileScribe` only saves function evaluations to memory while `VolatileScribe` saves them to the local file system.  Under many circumstances the user will probably just want to use the `@anamnesis` macro so that the scribe objects are hidden (though they can still be accessed through `Anamnesis.ScribeBox` see below).  In other cases the user may want more convenient access to the wrapper objects themselves.  This can be done by using the `@scribe` macro.  To create a scribe wrapper for a function `f` one should simply call `@scribe(f)`.  If one wants the scribe to store function evaluations in the local file system as well one should do `@scribe(dir, f)` where `dir` is the directory the function evaluations are stored in.  This will return the scribe wrapper.  For example


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


It works the same way with `NonVolatileScribe`, one simply has to pass a directory.  Note that the directory name only has to be passed once.  Once that has happened, Anamnesis knows that the wrapper for `f` needs to store to the file system.


<a id='API-Docs-1'></a>

## API Docs

<a id='Anamnesis.NonVolatileScribe' href='#Anamnesis.NonVolatileScribe'>#</a>
**`Anamnesis.NonVolatileScribe`** &mdash; *Type*.



```
NonVolatileScribe(f, name, dir)
```

This is essentially a wrapper for the function `f` (which is given the `Symbol` name `name`) which "memoizes" the function.  The "non-volatile" variant of the scribes hold the function evaluations on the local file system so that function evaluations can be stored between separate instances of a program.  Additionally, it has some methods for dealing with argument accuracy and size.

`NonVolatileScribe` uses "lazy" deserialization of files.  That is, any evaluations it has seen in a program instance are stored in memory, only when a new evaluation is made for which the scribe knows it has the result in a file, but lacks the result in local memory will it deserialize anything.  Furthermore, function evaluations are saved in completely separate  files so that deserialization time for a single function call doesn't depend on how many results are stored.

Note that all scribe objects identify functions purely by their names.

**"Promoting" `VolatileScribe`**

One can also do `VolatileScribe(s, dir)` where `s` is a `VolatileScribe`.  When this is done, the scribe will determine if the directory `dir` exists.  If it does, it will load all  function evaluations from there and merge those with any that it has already evaluated in the course of the program, which will also be stored to files in `dir`.  If `dir` does not exist, it will be created along with any evaluations that the scribe holds.


<a target='_blank' href='https://github.com/ExpandingMan/Anamnesis.jl/tree/4759322c189ad35a934d761e721eba8660621064/src/scribe.jl#L66-L90' class='documenter-source'>source</a><br>

<a id='Anamnesis.VolatileScribe' href='#Anamnesis.VolatileScribe'>#</a>
**`Anamnesis.VolatileScribe`** &mdash; *Type*.



```
VolatileScribe(f, name)
```

This is essentially a wrapper for the function `f` (which is given the `Symbol` name `name`) which "memoizes" the function.  The "volatile" variant of the scribes holds function  evaluations in the program memory, so this version is close to a straight-forward `memoize` implementation.  In addition, it has some methods for dealing with argument accuracy and size, as well as some methods for easily converting into `NonVolatileScribe`.

Note that all scribe objects identify functions purely by their names.


<a target='_blank' href='https://github.com/ExpandingMan/Anamnesis.jl/tree/4759322c189ad35a934d761e721eba8660621064/src/scribe.jl#L44-L54' class='documenter-source'>source</a><br>

<a id='Anamnesis.execute!-Tuple{Anamnesis.AbstractScribe,Vararg{Any,N}}' href='#Anamnesis.execute!-Tuple{Anamnesis.AbstractScribe,Vararg{Any,N}}'>#</a>
**`Anamnesis.execute!`** &mdash; *Method*.



```
execute!(scr, args...)
```

This is an alias for calling the scribe object.  It is useful to have this form for writing some of the macro code.


<a target='_blank' href='https://github.com/ExpandingMan/Anamnesis.jl/tree/4759322c189ad35a934d761e721eba8660621064/src/scribe.jl#L217-L222' class='documenter-source'>source</a><br>

<a id='Anamnesis.forget!-Tuple{Anamnesis.AbstractScribe,Vararg{Any,N}}' href='#Anamnesis.forget!-Tuple{Anamnesis.AbstractScribe,Vararg{Any,N}}'>#</a>
**`Anamnesis.forget!`** &mdash; *Method*.



```
forget!(scr, args...)
```

Delete the records of a particular function call saved by the scribe object `scr`.  If these are stored in the files system, the appropriate files will be deleted as well.

Note that this will *not* throw an error if the entry for the arguments provided do not exist.


<a target='_blank' href='https://github.com/ExpandingMan/Anamnesis.jl/tree/4759322c189ad35a934d761e721eba8660621064/src/scribe.jl#L227-L235' class='documenter-source'>source</a><br>

<a id='Anamnesis.purge-Tuple{String}' href='#Anamnesis.purge-Tuple{String}'>#</a>
**`Anamnesis.purge`** &mdash; *Method*.



```
purge(scr)
purge(dir)
```

Delete a directory and its contents.  If an `AbstractScribe` argument is provided, the directory will be deleted, and a non-volatile scribe object will be returned.  


<a target='_blank' href='https://github.com/ExpandingMan/Anamnesis.jl/tree/4759322c189ad35a934d761e721eba8660621064/src/scribe.jl#L253-L259' class='documenter-source'>source</a><br>

<a id='Anamnesis.refresh!-Tuple{Anamnesis.AbstractScribe,Vararg{Any,N}}' href='#Anamnesis.refresh!-Tuple{Anamnesis.AbstractScribe,Vararg{Any,N}}'>#</a>
**`Anamnesis.refresh!`** &mdash; *Method*.



```
refresh!(scr, args...)
```

Re-calculate the value of the function associated with the scribe object `scr`, storing the new value in the ways it would normally be stored after a function call with the type of scribe object given.


<a target='_blank' href='https://github.com/ExpandingMan/Anamnesis.jl/tree/4759322c189ad35a934d761e721eba8660621064/src/scribe.jl#L268-L274' class='documenter-source'>source</a><br>

<a id='Anamnesis.scribe-Tuple{Function,Symbol}' href='#Anamnesis.scribe-Tuple{Function,Symbol}'>#</a>
**`Anamnesis.scribe`** &mdash; *Method*.



```
scribe(f, name)
scribe(f, name, dir)
```

Create a scribe object for function `f` of name `name`.  This will be a `NonVolatileScribe`  if a directory is supplied or a `VolatileScribe` otherwise.

Note that these functions do not store the functions in the Anamnesis module.

Under most circumstances it is recomended that users use the `@scribe` macro instead.


<a target='_blank' href='https://github.com/ExpandingMan/Anamnesis.jl/tree/4759322c189ad35a934d761e721eba8660621064/src/scribe.jl#L316-L326' class='documenter-source'>source</a><br>

<a id='Anamnesis.@scribe-Tuple{Any}' href='#Anamnesis.@scribe-Tuple{Any}'>#</a>
**`Anamnesis.@scribe`** &mdash; *Macro*.



```
@scribe(f)
@scribe(dir, f)
```

Create a "scribe" object from the function `f`.  The "scribe" object is essentially a wrapper that when called will evaluate `f` while memorizing the results, either in memory or, in the case where a directory `dir` is provided, on the local file system.

Additionally, the "scribe" object will be stored in the Anamnesis module in a dictionary called `ScribeBox` the keys of which are the function name.  Calling `@scribe` when a  function with the name of `f` already exists in `ScribeBox` will retrieve that scribe  instead of creating a new one.

Note that functions are identified entirely by name, so this macro will confuse distinct functions which are given the same name, regardless of scope.


<a target='_blank' href='https://github.com/ExpandingMan/Anamnesis.jl/tree/4759322c189ad35a934d761e721eba8660621064/src/scribe.jl#L332-L347' class='documenter-source'>source</a><br>

