__precompile__(true)

module Anamnesis

using MacroTools

using Core.Compiler: return_type


include("utils.jl")
include("scribe.jl")
include("macros.jl")

export VolatileScribe
export call
export @scribeof, @mem, @localmem, @scribe, @localscribe, @rawcall, @rawfunc, @scribeofrawfunc, @anamnesis

end
