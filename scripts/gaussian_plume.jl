using DrWatson
@quickactivate

using Dates
using GRIBDatasets
using Plots
using JLD2


include(srcdir("parameters.jl"))
include(srcdir("gributils.jl"))
include(srcdir("gaussian.jl"))

simname = "OPER_PG"

relstart = DateTime(RELSTART)

inputdir = "/home/tcarion/projects/sckcen/data/extractions/OPER_20190515/output"

times = RELEASE_TIMES

@time meteo_ecmwf = extract_meteo_ecmwf(inputdir, RELEASE_TIMES)

winds = process_wind.(meteo_ecmwf)

##
grid = CenteredGrid()
grid_array = collect(grid)

@time concentration, TIC = gaussian_puffs(
    grid,
    times,
    [w[1] for w in winds],
    [w[2] for w in winds],
    RELEASE_RATE,
    RELHEIGHT
)

# concentration, TIC = gaussian_puffs(
#     grid,
#     times,
#     [2, 5, 10, 5, 2, 3],
#     [0, 45, 90, 135, 180, 225],
#     RELEASE_RATE,
#     RELHEIGHT
# )

jldsave(concentrationfile(simname); concentration, TIC)

Xs = dims(concentration, X) |> collect
Ys = dims(concentration, Y) |> collect

contourf(Xs, Ys, permutedims(concentration[:,:,1, 1]))
contourf(Xs, Ys, permutedims(TIC[:,:,1]))
##

# contour(u_array[:,:,1])
# heatmap(v_array[:,:,1])
# stack = Raster(nearest_input_path)

# ! Why the second valid_time is the start of the 
valid_times = GRIBDatasets.DEFAULT_EPOCH .+ Second.(collect(ds["valid_time"]))
# 2-element Vector{DateTime}:
#  2019-05-15T15:00:00
#  2019-05-15T00:00:00
valid_times = GRIBDatasets.DEFAULT_EPOCH .+ Second.(collect(GRIBDataset(getpath(inputs[3]))["valid_time"]))
