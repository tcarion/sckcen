using DrWatson
using DataFrames
using JLD2

include(srcdir("read_datasheet.jl"))

sensors_dose_rates = read_dose_rate_sensors()
background_stats = calc_background(sensors_dose_rates)

# mean_and_stds_df = DataFrame(get_first_from_name.(calc_background(sensors_dose_rates) |> Ref, keys(dose_rates_results)))

jldsave(MEASURES_SAVENAME; background_stats)