using DrWatson
using JLD2
using DataFramesMeta
@quickactivate

include(srcdir("outputs.jl"))
include(srcdir("process_doserates.jl"))
include(srcdir("read_datasheet.jl"))

simname = "FirstPuff_ELDA_res=0.0001_timestep=10_we=1000.0"
postprocess_path = dose_rate_process_savename(simname)

dose_rates_results = load(dose_rate_savename(simname))

dose_rates_df = ensemble_dose_rates_to_df(dose_rates_results)
dose_rates_stats = mean_and_std(dose_rates_df)

JLD2.jldsave(postprocess_path; dose_rates_df, dose_rates_stats)
# @chain dose_rates_df begin
#     @rsubset :receptorName == "IMR/M03"
#     @rsubset :times == DateTime("2019-05-15T15:20:00")
# end

ranks = talagrand(@rsubset dose_rates_df :receptorName in ["IMR/M03", "IMR/M04", "IMR/M15"])


histogram(ranks; 
    bins = 1:1:12,
    xticks = 1:1:11,
    legend = false
)
# flexpart_M03.H10_rank = ordinalrank(flexpart_M03.H10)