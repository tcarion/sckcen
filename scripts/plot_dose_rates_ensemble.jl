using DrWatson
using Plots
using JLD2
using DataFramesMeta

include(srcdir("process_doserates.jl"))
include(srcdir("read_datasheet.jl"))

SHIFT_DATE = true
PLOT_MEMBERS = true

simname = "FirstPuff_ELDA_res=0.0001_timestep=10_we=1000.0"
simname = "FirstPuff_OPER_PF_20230329_res=0.0005"
dose_rate_data_path = dose_rate_savename(simname)

sensors_dose_rates = read_dose_rate_sensors()
dose_rates_results = load(dose_rate_data_path)
dose_rates_df = ensemble_dose_rates_to_df(dose_rates_results)
dose_rates_stats = mean_and_std(dose_rates_df)
sensors_background = read_background_stats()

plotdirpath = mkpath(plotsdir("experimental", "dose_rates", simname))

plots = map(collect(pairs(dose_rates_results))) do (sensor_name, results)
    stats = subset(sensors_background, :longName => x -> x .== sensor_name) |> first
    mean_background = stats.value_mean
    std_background = stats.value_std
    receptor = filter_sensor(sensors_dose_rates, sensor_name)
    dose_rate_stat = @rsubset dose_rates_stats :receptorName == sensor_name
    timeserie_control, D_control, H10_control = results[1]

    basedate = Date(timeserie_control[1])
    basetime_start = Time(15, 20)
    basetime_end = Time(16, 10)

    receptor_times = SHIFT_DATE ? DateTime.(basedate, Time.(receptor.stop)) : receptor.stop
    
    dt_start = DateTime(basedate, basetime_start)
    dt_stop = DateTime(basedate, basetime_end)
    xticks = dt_start:Dates.Minute(10):dt_stop

    h10plot = Plots.plot(
        timeserie_control, H10_control,
        label = "Flexpart - control",
        # marker = :dot,
        # color = :red,
        xlims = (dt_start - Minute(2), dt_stop + Minute(2)),
        # ylims = (-2, 6),
        xticks = (xticks, [Dates.format(x, "HH:MM") for x in xticks]),
        xrotation = 45,
        grid = false,
        markerstrokecolor=:auto
    )
    plot!(
        dose_rate_stat.times, dose_rate_stat.H10_mean,
        yerror = 2*dose_rate_stat.H10_std,
        label = "Flexpart - mean",
    )

    if PLOT_MEMBERS
        imembers = unique(dose_rates_df[:, :member])
        for i in imembers
            tp = @rsubset dose_rates_df :member == i
            tp = @rsubset tp :receptorName == sensor_name
            Plots.plot!(
                tp.times, tp.H10,
                # marker = :dot,
                # color = :red,
                label = false,

                linewidth = 1,
            )
        end
    end
    # plot!(h10plot,
    #     receptor_times, 
    #     receptor.value .- mean_background,
    #     label = sensor_name,
    #     yerror = 2*std_background,
    #     # marker = :dot,
    #     markerstrokecolor=:auto
    # )
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