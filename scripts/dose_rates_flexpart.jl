using DrWatson
@quickactivate
using Sckcen
using Unitful
using Rasters
using Rasters: dims as ddims
import NCDatasets
using JLD2
using Flexpart

include(srcdir("read_datasheet.jl"))
include(srcdir("process_doserates.jl"))
include(srcdir("outputs.jl"))

element_id = :Se75
simname = "FirstPuff_OPER_PF_20230329_res=0.0005"
simname = "FirstPuff_OPER_res=0.0001_timestep=10_we=5000.0"
simname = "FirstPuff_OPER_res=0.0001_timestep=10_we=1000.0"
simname = "FirstPuff_ELDA_res=0.0001_timestep=10_we=1000.0"
simname = "ENFO_BE_20190515T00_res=0.0001_timestep=10_we=1000.0"
simname = "ENFO_BE_20190513T00_res=0.0001_timestep=10_we=1000.0"
simname = "ENFO_BE_20190514T12_res=0.0001_timestep=10_we=1000.0"
simname = "ENFO_BE_20190514T00_res=0.0001_timestep=10_we=1000.0"
simname = "ENFO_BE_20190513T12_res=0.0001_timestep=10_we=1000.0"
is_ensemble = true
DOSE_RATE_SAVENAME = dose_rate_savename(simname)

rho = 0.001161u"g/cm^3"
nuclide_data = read_lara_file("Se-75")

sensor_numbers = [0, 1, 2, 3, 4, 7, 8, 12, 14, 15]
# sensor_numbers = [3, 4, 15]
# sensor_numbers = [3]

if is_ensemble
    output = get_outputs(simname)
    conc_mass = isempty(output) ? combine_ensemble_outputs(simname) : Raster(getpath(first(output)))
    conc = prepare_output_for_doserate(conc_mass)
else
    conc = prepare_output_for_doserate(simname)
end
conc = Rasters.setcrs(conc, EPSG(4326))
times = ddims(conc, Ti) |> collect

sensors_dose_rates = read_dose_rate_sensors()

## Calculate dose rates
@info "Starting dose rates computation for simulation: $simname"
@time dose_rates_da = if is_ensemble
    dose_for_each_member = map(ddims(conc, :member)) do imember
        @info "Computing membmer $imember"
        @time compute_dose_rates(conc[member = At(imember)], sensor_numbers, sensors_dose_rates, nuclide_data)
    end

    # dose_for_each_member = mapslices(conc[:,:,:,:,1:2]; dims = :member) do one_member
    #     # @info "Computing membmer $(refdims(one_member, :member)[1])"
    #     println(typeof(one_member))
    #     # compute_dose_rates(one_member, sensor_numbers, sensors_dose_rates, nuclide_data)
    # end

    cat(dose_for_each_member...; dims = ddims(conc, :member))
else
    compute_dose_rates(conc, sensor_numbers, sensors_dose_rates, nuclide_data)
end
# 61.162754 seconds (520.17 M allocations: 18.220 GiB, 5.45% gc time)
# now: 152.530969 seconds (2.21 M allocations: 44.482 GiB, 1.80% gc time, 0.66% compilation time)

dose_rates_da = DD.rebuild(dose_rates_da, metadata = Dict(
    "simtype" => "flexpart",
    "ensemble" => is_ensemble,
    "simname" => simname,
    "membertype" => is_ensemble ? "ensemble_forecast" : ""
))

## Save dose rates
save(dose_rate_file(simname), Dict(DOSE_RATES_SAVENAME => dose_rates_da))
@info "Dose rates saved at $(dose_rate_file(simname))"


##

## LEGACY
# Ey, I = first(zip(nuclide_data.Ey*u"keV", nuclide_data.I))
# mu, mu_en = attenuation_coefs(Ey, rho)
# prefac = _prefactor(Ey, mu_en, rho)
# receptor = [location_M03.lon, location_M03.lat, location_M03.alt]
# mux = _mux(mu, conc, receptor)
# B = _buildup_factor.(Ey, mux)

# q = 1.0 * _δV(conc) / 3.7e10

# Dr = _δDᵣ.(ustrip(prefac), q, B, mux, ustrip(mu))

# h10 = conc[Ti=1] .* factors_H10
# # interesting plot, to be compared to python code!!
# plot(log10.(h10[Z=1]))


# Btp = B[:,:,1,1]
# disty = 500 / 111320
# distx = 500 / 111320 / cosd(51)
# left = RELLON - distx 
# right = RELLON + distx
# bottom = RELLAT - disty
# top = RELLAT + disty

# zBtp = Btp[X(left..right), Y(bottom..top)]
# # We get the same B's as with ADDER
# heatmap(zBtp)
# savefig(joinpath(plotsdir("experimental", "dose_rates"), "buildup_factor_flexpart_M03.png"))


# heatmap(Dr[:,:,1,1][X(left..right), Y(bottom..top)])


# # location_M03 = (lat = 51.20, lon = 5.07, alt = 1.)
# # Coordinates from the source. Very similar to those found in example from adder-main (1-2 meters difference)
# location_M03_lla = LLA(get_sensor_location(sensors_dose_rates, 3)...)
# trans_enu(location_M03_lla) # [-157.2, -142.8] in adder-main
# trans_enu(LLA(get_sensor_location(sensors_dose_rates, 15)...))  # [-262.2, -121.6] in adder-main