using DrWatson
@quickactivate

using Dates
using GRIBDatasets
using Plots
using JLD2
using DataFrames
using DataFramesMeta

include(srcdir("parameters.jl"))
include(srcdir("gributils.jl"))
include(srcdir("gaussian.jl"))

simname = "OPER_PG"

relstart = DateTime(RELSTART)

inputdir = "/home/tricarion/Documents/sckcen/data/extractions/OPER_20190515/output"

times = RELEASE_TIMES
# meteo_df = DataFrame(load(datadir("meteo_ensemble.csv")))

@time meteo_ecmwf = extract_meteo_ecmwf(inputdir, RELEASE_TIMES .- Dates.Hour(2))

winds = process_wind.(meteo_ecmwf)

##
grid = CenteredGrid()

puff = GaussianPuff(
    grid,
    relstart,
    Minute.(RELSTEPS_MINUTE),
    [w[1] for w in winds],
    [w[2] for w in winds],
    RELEASE_RATE,
    RELHEIGHT
)

@time conc_da = gaussian_puffs(puff, times)
#   777.593 ms (16066330 allocations: 614.54 MiB)
# concentration, TIC = gaussian_puffs(
#     grid,
#     times,
#     [2, 5, 10, 5, 2, 3],
#     [0, 45, 90, 135, 180, 225],
#     RELEASE_RATE,
#     RELHEIGHT
# )

# save(concentrationfile(simname), Dict(GAUSSIAN_SAVENAME => conc_da))

# Xs = dims(concentration, X) |> collect
# Ys = dims(concentration, Y) |> collect

# contourf(Xs, Ys, permutedims(concentration[:,:,1, 1]))
# contourf(Xs, Ys, permutedims(TIC[:,:,1]))
##
