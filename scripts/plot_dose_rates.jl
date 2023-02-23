using DrWatson
using Plots
using JLD2

include(srcdir("read_datasheet.jl"))

simname = "FirstPuff_OPER_res=0.0001_timestep=10_we=1000.0"
DOSE_RATE_SAVENAME = dose_rate_savename(simname)

sensors_dose_rates = read_dose_rate_sensors()
dose_rates_results = load(DOSE_RATE_SAVENAME)
sensors_background = read_background_stats()

sensor_names = keys(dose_rates_results)

plotdirpath = mkpath(plotsdir("experimental", "dose_rates", simname))

plots = map(collect(pairs(dose_rates_results))) do (sensor_name, results)
    stats = subset(sensors_background, :longName => x -> x .== sensor_name) |> first
    mean_background = stats.value_mean
    std_background = stats.value_std
    receptor = filter_sensor(sensors_dose_rates, sensor_name)

    timeserie, D, H10 = results
    xticks = DateTime(2019,5,15,15,20):Dates.Minute(10):DateTime(2019,5,15,16,10)
    h10plot = plot(
        timeserie, H10, 
        label = "Flexpart",
        marker = :dot,
        xlims = (DateTime(2019,5,15,15,18), DateTime(2019,5,15,16,12)),
        ylims = (-2, 6),
        xticks = (xticks, [Dates.format(x, "HH:MM") for x in xticks]),
        xrotation = 45,
        grid = false,
        markerstrokecolor=:auto
    
    )
    plot!(h10plot,
        receptor.stop, 
        receptor.value .- mean_background,
        label = sensor_name,
        yerror = 2*std_background,
        marker = :dot,
        markerstrokecolor=:auto
    )
    savefig(joinpath(plotdirpath, "telerad_vs_flexpart_$(split(sensor_name, "/")[2]).png"))
    h10plot
end

# plot(ts, D, marker = :dot, xlims = (DateTime(2019,5,15,15,10), DateTime(2019,5,15,16,10)), xrotation = 20)
# plot(M03.stop, M03.value .- get_first_from_name(mean_and_std, 3).value_mean)
##

# layout = @layout [a  b  c]
# sps = plot(plots..., layout = layout)