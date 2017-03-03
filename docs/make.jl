#!/usr/bin/julia
using Anamnesis
using Documenter

makedocs()

# copy the resulting document to the README
fname = joinpath("build", "README.md")
if isfile(fname)
    info("Updating README...")
    cp(fname, joinpath("..", "README.md"), remove_destination=true)
end
