using DrWatson
using Plots
using JLD2

include(srcdir("process_doserates.jl"))
include(srcdir("read_datasheet.jl"))

simname = "FirstPuff_ELDA_res=0.0001_timestep=10_we=1000.0"
dose_rate_data_path = dose_rate_savename(simname)

sensors_dose_rates = read_dose_rate_sensors()
dose_rates_results = load(dose_rate_data_path)
dose_rates_stats = Dict(
    sensor_name => mean_and_std(ensemble_dose_rates_to_df(result)) 
        for (sensor_name, result) in pairs(dose_rates_results)
)
sensors_background = read_background_stats()

plotdirpath = mkpath(plotsdir("experimental", "dose_rates", simname))

plots = map(collect(pairs(dose_rates_results))) do (sensor_name, results)
    stats = subset(sensors_background, :longName => x -> x .== sensor_name) |> first
    mean_background = stats.value_mean
    std_background = stats.value_std
    receptor = filter_sensor(sensors_dose_rates, sensor_name)
    dose_rate_stat = dose_rates_stats[sensor_name]
    timeserie_control, D_control, H10_control = results[1]
    xticks = DateTime(2019,5,15,15,20):Dates.Minute(10):DateTime(2019,5,15,16,10)
    h10plot = plot(
        timeserie_control, H10_control,
        label = "Flexpart - control",
        # marker = :dot,
        # color = :red,
        xlims = (DateTime(2019,5,15,15,18), DateTime(2019,5,15,16,12)),
        ylims = (-2, 6),
        xticks = (xticks, [Dates.format(x, "HH:MM") for x in xticks]),
        xrotation = 45,
        grid = false,
        markerstrokecolor=:auto
    )
    plot!(
        dose_rate_stat.times, dose_rate_stat.H10_mean,
        yerror = 2*dose_rate_stat.H10_std,
        label = "Flexpart - mean",
        # marker = :dot,
        # color = :blue,
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
        # marker = :dot,
        markerstrokecolor=:auto
    )
    savefig(joinpath(plotdirpath, "telerad_vs_flexpart_$(split(sensor_name, "/")[2]).png"))
    h10plot
end

# plot(
#         receptor.stop, 
#         receptor.value,
#         label = sensor_name,
#         yerror = 2*receptor.value_std,
#         # marker = :dot,
#         markerstrokecolor=:auto,
#         xlims = (DateTime(2019,5,15,15,18), DateTime(2019,5,15,16,12)),
#     )

# plot(ts, D, marker = :dot, xlims = (DateTime(2019,5,15,15,10), DateTime(2019,5,15,16,10)), xrotation = 20)
# plot(M03.stop, M03.value .- get_first_from_name(mean_and_std, 3).value_mean)
##

# layout = @layout [a  b  c]
# sps = plot(plots..., layout = layout)