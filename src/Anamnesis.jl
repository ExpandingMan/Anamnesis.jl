__precompile__(true)

module Anamnesis

using MacroTools
using JLD

# TODO write forget macros
# TODO implement size limits for hashing
# TODO handle different orderings of keyword arguments
# TODO consider using HDF5 or JLD for main storage (how would this work?)


const METADATA_FILENAME = "metadata.jld"
const FILENAME_RANDSTRING_LENGTH = 12
const ARGHASH_FLOAT_DIGITS = 12


include("scribe.jl")
include("filesystem.jl")
include("anamnesis.jl")


function __init__()
    global const ScribeBox = Dict{Symbol,AbstractScribe}()
end

end
