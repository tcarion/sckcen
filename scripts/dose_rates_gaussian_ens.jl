using DrWatson
using JLD2
using Sckcen
using Geodesy
using DimensionalData

include(srcdir("projections.jl"))
include(srcdir("gaussian.jl"))
include(srcdir("parameters.jl"))
include(srcdir("read_datasheet.jl"))
include(srcdir("process_doserates.jl"))

element_id = :Se75
simname = "OPER_PG_ENS"
sensors_dose_rates = read_dose_rate_sensors()

nuclide_data = read_lara_file("Se-75")

sensor_numbers = [0, 1, 2, 3, 4, 7, 8, 12, 14, 15]

puffs = load(concentrationfile(simname))[GAUSSIAN_SAVENAME]

fcstarts = collect(keys(puffs))
dose_rates_da_by_fcstart = map(fcstarts) do fcstart
    puff = puffs[fcstart]
    conc = puff[CONC_LAYERNAME]
    @info "Compute fcstart: $fcstart"
    memberdim = ddims(conc, :member)
    dose_for_each_member = map(memberdim) do imember
        @info "Computing membmer $imember"
        @time compute_dose_rates(conc[member = At(imember)], sensor_numbers, sensors_dose_rates, nuclide_data)
    end

    cat(dose_for_each_member...; dims = memberdim)
    # time:  7.469 s (45033782 allocations: 6.49 GiB)
end

dose_rates_da = cat(dose_rates_da_by_fcstart...; dims = Dim{:fcstart}(fcstarts))

dose_rates_da = DimensionalData.rebuild(dose_rates_da, metadata = Dict(
    "simtype" => "gaussian",
    "ensemble" => true,
))


## Save dose rates
save(dose_rate_file(simname), Dict(DOSE_RATES_SAVENAME => dose_rates_da))

## not easy to rebuild dims... it's 
# newdims = map(DimensionalData.dims(dose_rates_da)) do ddd
#     if DimensionalData.name(ddd) == :names
#         Dim{:sensor}(ddd.val)
#     else
#         ddd
#     end
# end

# rebuild(dose_rates_da, dims = newdims)    