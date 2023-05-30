using DrWatson
@quickactivate

using JLD2
using DimensionalData: dims as ddims, metadata as dmetadata
using Sckcen

include(srcdir("montecarlo.jl"))
include(srcdir("process_doserates.jl"))
include(srcdir("read_datasheet.jl"))

simname = "OPER_PG_LOGNORM_AZIMUTH"

DOSE_RATE_SAVENAME = joinpath(mc_gaussiandir(simname), DOSE_RATES_FILENAME)

sensors_dose_rates = read_dose_rate_sensors()
nuclide_data = read_lara_file("Se-75")
sensor_numbers = [0, 1, 2, 3, 4, 7, 8, 12, 14, 15]

puffs = load(mc_concentrationfile(simname))[MC_GAUSSIAN_SAVENAME]

dose_for_each_member = map(ddims(puffs, :member)) do imember
    @info "Computing member $imember"
    compute_dose_rates(puffs[:conc][member = At(imember)], sensor_numbers, sensors_dose_rates, nuclide_data)
end

dose_rates_da = cat(dose_for_each_member...; dims = ddims(puffs, :member))

dose_rates_da = DimStack(dose_rates_da...; 
    metadata = dmetadata(puffs)
)

## Save dose rates
save(DOSE_RATE_SAVENAME, Dict(DOSE_RATES_SAVENAME => dose_rates_da))
@info "Dose rates saved at $DOSE_RATE_SAVENAME"