using DrWatson
using JLD2
using Sckcen
using Geodesy

include(srcdir("projections.jl"))
include(srcdir("gaussian.jl"))
include(srcdir("parameters.jl"))
include(srcdir("read_datasheet.jl"))

element_id = :Se75
simname = "OPER_PG"
sensors_dose_rates = read_dose_rate_sensors()

rho = 0.001161u"g/cm^3"
nuclide_data = read_lara_file("Se-75")

sensor_numbers = [0, 1, 2, 3, 4, 7, 8, 12, 14, 15]

# @time enu_sensor_locations = map(eachrow(sensors_dose_rates)) do row
#     lla_to_enu(LLA(lat = row.lat, lon = row.lon))
# end

# sensors_dose_rates.x = [p.e for p in enu_sensor_locations]
# sensors_dose_rates.y = [p.n for p in enu_sensor_locations]

loaded = load(concentrationfile(simname))

concentration = loaded["concentration"]
TIC = loaded["TIC"]

times = dims(concentration, Ti) |> collect


@time dose_rates = map(sensor_numbers) do sensor_number
    location_receptor = get_sensor_location(sensors_dose_rates, sensor_number)

    receptor = trans_enu(LLA(; location_receptor...))

    D, H10 = time_resolved_dosimetry(concentration, receptor, nuclide_data, rho)
    return (; times, D, H10)
end
# time:  7.469 s (45033782 allocations: 6.49 GiB)

## Save dose rates
data_to_save = Dict(
    _name_from_number(sensor_number) => dose_rate for (dose_rate, sensor_number) in zip(dose_rates, sensor_numbers)
)
save(doseratefile(simname), data_to_save)