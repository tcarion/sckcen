using DrWatson
@quickactivate
@time using CairoMakie

include(srcdir("plots.jl"))
include(srcdir("process_doserates.jl"))

simnames = ["OPER_PG", "FirstPuff_OPER_res=0.0001_timestep=10_we=1000.0", "FirstPuff_OPER_res=0.0001_timestep=10_we=5000.0"]
simnames = ["OPER_PG", "FirstPuff_OPER_res=0.0001_timestep=10_we=1000.0", "FirstPuff_OPER_res=0. 0001_timestep=10_we=5000.0"]
simnames = ["FirstPuff_ELDA_res=0.0001_timestep=10_we=1000.0", "FirstPuff_OPER_res=0.0001_timestep=10_we=1000.0"]
simnames = ["OPER_PG_LOGNORM_AZIMUTH"]

sensor_numbers = [3, 4, 15, 2]

results_df = merge_dose_rates_results(simnames)

dose_rates_df = join_dose_rates_sensors(results_df)

dose_rates_df = filter_receptors(dose_rates_df, sensor_numbers)

f = plot_smart_doses(dose_rates_df; Ncols = 2)

# save(plotsdir("dose_rates_plot.svg"), f)