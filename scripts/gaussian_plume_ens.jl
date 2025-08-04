using DrWatson
@quickactivate

using Dates
using GRIBDatasets
using Plots
using JLD2
using DimensionalData: dims as ddims


include(srcdir("parameters.jl"))
include(srcdir("gributils.jl"))
include(srcdir("gaussian.jl"))

simname = "OPER_PG_ENS"

fcstartmap = Dict(
     astimezone(ZonedDateTime(2019,5,13,00,00,00, tz"UTC"), tz"Europe/Brussels") => "2019051300",
     astimezone(ZonedDateTime(2019,5,13,12,00,00, tz"UTC"), tz"Europe/Brussels") => "2019051312",
     astimezone(ZonedDateTime(2019,5,14,00,00,00, tz"UTC"), tz"Europe/Brussels") => "2019051400",
     astimezone(ZonedDateTime(2019,5,14,12,00,00, tz"UTC"), tz"Europe/Brussels") => "2019051412",
     astimezone(ZonedDateTime(2019,5,15,00,00,00, tz"UTC"), tz"Europe/Brussels") => "2019051500",
)

relstart = DateTime(RELSTART)

times = RELEASE_TIMES
inputdirpath(date) = joinpath(datadir(), "extractions","ENFO", date, "PF")

allpuffs = Dict()
members=1:50

for (fcstart, v) in fcstartmap
    inputdir = inputdirpath(v)
    @info "Computing fcstart: $fcstart"
    conc_for_each_member = map(members) do imember
        @info "Computing member $imember"
        @time meteo_ecmwf = extract_meteo_ecmwf(inputdir, RELEASE_TIMES, member = imember)
        winds = process_wind.(meteo_ecmwf)
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
    end
    allpuffs[fcstart] = cat(conc_for_each_member...; dims = Dim{:member}(members))
end


save(concentrationfile(simname), Dict(GAUSSIAN_SAVENAME => allpuffs))
##
#   777.593 ms (16066330 allocations: 614.54 MiB)
# concentration, TIC = gaussian_puffs(
#     grid,
#     times,
#     [2, 5, 10, 5, 2, 3],
#     [0, 45, 90, 135, 180, 225],
#     RELEASE_RATE,
#     RELHEIGHT
# )


# Xs = dims(concentration, X) |> collect
# Ys = dims(concentration, Y) |> collect

# contourf(Xs, Ys, permutedims(concentration[:,:,1, 1]))
# contourf(Xs, Ys, permutedims(TIC[:,:,1]))
##
