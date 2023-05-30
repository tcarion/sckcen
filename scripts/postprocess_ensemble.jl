using DrWatson
using JLD2
using DataFramesMeta
@quickactivate

include(srcdir("outputs.jl"))
include(srcdir("process_doserates.jl"))
include(srcdir("read_datasheet.jl"))

simname = "FirstPuff_ELDA_res=0.0001_timestep=10_we=1000.0"
simname = "OPER_PG_LOGNORM_AZIMUTH"
postprocess_path = dose_rate_process_savename(simname)

dose_rates_df = dose_rates_to_df(simname)
dose_rates_df = @rsubset dose_rates_df :receptorName in ["IMR/M03", "IMR/M04", "IMR/M15"]
# @chain dose_rates_df begin
#     @rsubset :receptorName == "IMR/M03"
#     @rsubset :times == DateTime("2019-05-15T15:20:00")
# end

ranks = talagrand(dose_rates_df)


hist(ranks.rank; 
    bins = 5,
    # xticks = 1:1:11,
)
# flexpart_M03.H10_rank = ordinalrank(flexpart_M03.H10)