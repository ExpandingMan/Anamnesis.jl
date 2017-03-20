__precompile__(true)

module Anamnesis
using DataUtils

# TODO write forget macros
# TODO implement size limits for hashing
# TODO handle different orderings of keyword arguments


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
