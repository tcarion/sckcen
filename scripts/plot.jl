using DrWatson
using CairoMakie

include(srcdir("fp_plot.jl"))

simname = "fp_test"

outfile = first(get_output(simname))

stack = RasterStack(outfile)

spec = Raster(outfile)

heatmap(spec[height = 1, Ti = 10] |> Matrix)