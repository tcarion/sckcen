using DrWatson
@quickactivate

using Dates
using TimeZones
using GRIBDatasets
using Plots
using JLD2
using DimensionalData: dims as ddims
using DataFrames

include(srcdir("parameters.jl"))
include(srcdir("gributils.jl"))
include(srcdir("gaussian.jl"))


# filepath = datadir("meteo_ensemble.jld2")
filepath = datadir("meteo_ensemble.csv")


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

members=1:50

t = Ti(RELEASE_TIMES)
memdim = Dim{:member}(members)
fcstartdim = Dim{:fcstart}(sort(collect(keys(fcstartmap))))

u = zeros((t, memdim, fcstartdim), name = :u)
v = zeros((t, memdim, fcstartdim), name = :v)
leadtime1 = zeros(Int, (fcstartdim,), name = :leadtime1)
leadtime2 = zeros(Int, (fcstartdim,), name = :leadtime2)

meteo_stack = DimStack(u, v, leadtime1, leadtime2)
for fcstart in val(fcstartdim)
    startstr = fcstartmap[fcstart]
    inputdir = inputdirpath(startstr)
    @info "Computing fcstart: $fcstart"
    for imember in members
        @info "Computing member $imember"
        @time meteo_ecmwf = extract_meteo_ecmwf(inputdir, RELEASE_TIMES, member = imember)
        meteo_stack[:u][member=At(imember), fcstart=At(fcstart)] = [m.u for m in meteo_ecmwf] 
        meteo_stack[:v][member=At(imember), fcstart=At(fcstart)] = [m.v for m in meteo_ecmwf] 
        meteo_stack[:leadtime1][fcstart=At(fcstart)] = meteo_ecmwf[1].lt1
        meteo_stack[:leadtime2][fcstart=At(fcstart)] = meteo_ecmwf[1].lt2
    end
end


save(filepath, DataFrame(meteo_stack))