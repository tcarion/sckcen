using DrWatson
using Sckcen
using Unitful
using Rasters
using Plots

const DD = Rasters.DimensionalData

include(srcdir("outputs.jl"))
include(srcdir("read_datasheet.jl"))
include(srcdir("projections.jl"))
include(srcdir("outputs.jl"))

element_id = :Se75
simname = "FirstPuff_OPER_res=0.0001_timestep=10_we=1000.0"
rho = 0.001161u"g/cm^3"
nuclide_data = read_lara_file("Se-75")

sensor_numbers = [3, 4, 15]
sensor_numbers = [3]

conc_mass = Raster(string(get_outputs(simname)[1]); name = :spec001_mr)
replace!(conc_mass, NaN => 0.)
conc_mass = sum(conc_mass; dims = :pointspec)[pointspec = 1, nageclass = 1]

conc = convert_to_bq(conc_mass)
conc = set(conc, :height => Z)
Xdim = dims(conc, X)
xs = round.(Float64.(Xdim); sigdigits = 7) 
Ydim = dims(conc, Y)
ys = round.(Float64.(Ydim); sigdigits = 7) 
conc = set(conc, X => DD.Regular(xs[2] - xs[1]), Y => DD.Regular(ys[2] - ys[1]))
conc = set(conc, X => xs, Y => ys)

sensors_dose_rates = read_dose_rate_sensors()

H10s = map(sensor_numbers) do sensor_number
    location_receptor = get_sensor_location(sensors_dose_rates, sensor_number)
    receptor = [location_receptor.lon, location_receptor.lat, location_receptor.alt]
    
    # factors_D, factors_H10 = gamma_dose_rate_factors(conc[Ti = 1], location_receptor, nuclide_data, rho)
    _, H10 = time_resolved_dosimetry(conc, location_receptor, nuclide_data, rho)
    return H10
end

# plot(ts, D, marker = :dot, xlims = (DateTime(2019,5,15,15,10), DateTime(2019,5,15,16,10)), xrotation = 20)
# plot(M03.stop, M03.value .- get_first_from_name(mean_and_std, 3).value_mean)
##
plotdirpath = mkpath(plotsdir("experimental", "dose_rates", simname))

plots = map(zip(sensor_numbers, H10s)) do (sensor_number, H10)
    mean_and_std = get_first_from_name(calc_background(sensors_dose_rates), sensor_number)
    mean_background = mean_and_std.value_mean
    std_background = mean_and_std.value_std
    receptor = filter_sensor(sensors_dose_rates, sensor_number)

    ts = dims(conc, Ti) |> collect
    xticks = DateTime(2019,5,15,15,20):Dates.Minute(10):DateTime(2019,5,15,16,10)
    sensorname = receptor[1, :longName]
    h10plot = plot(
        ts, H10, 
        label = "Flexpart",
        marker = :dot,
        xlims = (DateTime(2019,5,15,15,18), DateTime(2019,5,15,16,12)),
        xticks = (xticks, [Dates.format(x, "HH:MM") for x in xticks]),
        xrotation = 45,
        grid = false,
        markerstrokecolor=:auto
    
    )
    plot!(h10plot,
        receptor.stop, 
        receptor.value .- mean_background,
        label = sensorname,
        yerror = 2*std_background,
        marker = :dot,
        markerstrokecolor=:auto
    )
    savefig(joinpath(plotdirpath, "telerad_vs_flexpart_$(split(sensorname, "/")[2]).png"))
    h10plot
end

# layout = @layout [a  b  c]
# sps = plot(plots..., layout = layout)

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