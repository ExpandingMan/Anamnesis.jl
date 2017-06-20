__precompile__(true)

module Anamnesis
using DataUtils
using DataTables

# TODO write forget macros
# TODO implement size limits for hashing
# TODO handle different orderings of keyword arguments
# TODO implement metadata as HDF5, so you don't have to reload the whole damn thing
# TODO consider using HDF5 or JLD for main storage (how would this work?)


const METADATA_FILENAME = "metadata.jbin"
const FILENAME_RANDSTRING_LENGTH = 12
ARGHASH_FLOAT_DIGITS = 12


include("scribe.jl")
include("filesystem.jl")
include("anamnesis.jl")


function __init__()
    global ScribeBox = Dict{Symbol,AbstractScribe}()
end

end
