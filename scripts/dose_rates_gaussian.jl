using DrWatson
using JLD2
using Sckcen
using Geodesy

include(srcdir("projections.jl"))
include(srcdir("gaussian.jl"))
include(srcdir("parameters.jl"))
include(srcdir("read_datasheet.jl"))
include(srcdir("process_doserates.jl"))

element_id = :Se75
simname = "OPER_PG"
sensors_dose_rates = read_dose_rate_sensors()

nuclide_data = read_lara_file("Se-75")

sensor_numbers = [0, 1, 2, 3, 4, 7, 8, 12, 14, 15]

puffs = load(concentrationfile(simname))[GAUSSIAN_SAVENAME]

concentration = puffs[CONC_LAYERNAME]

@time dose_rates = gaussian_dose_rates(concentration, sensor_numbers, sensors_dose_rates, nuclide_data)
# time:  7.469 s (45033782 allocations: 6.49 GiB)

sensor_names = _name_from_number.(sensor_numbers)

dose_rates_da = cat(dose_rates..., dims = Dim{:sensor}(sensor_names))

## Save dose rates
save(doseratefile(simname), Dict(DOSE_RATES_SAVENAME => dose_rates_da))

## not easy to rebuild dims... it's 
# newdims = map(DimensionalData.dims(dose_rates_da)) do ddd
#     if DimensionalData.name(ddd) == :names
#         Dim{:sensor}(ddd.val)
#     else
#         ddd
#     end
# end

# rebuild(dose_rates_da, dims = newdims)