module Anamnesis
# TODO make DataFrames dependency conditional and remove DatasToolbox dependency
using DatasToolbox
using DataFrames

# TODO implement kwargs



const METADATA_FILENAME = "metadata.jbin"
const FILENAME_RANDSTRING_LENGTH = 12
ARGHASH_FLOAT_DIGITS = 12


abstract AbstractScribe

# these are scribes that are getting stored for macros
ScribeBox = Dict{Symbol,AbstractScribe}()


include("filesystem.jl")
include("scribe.jl")
include("anamnesis.jl")


end
