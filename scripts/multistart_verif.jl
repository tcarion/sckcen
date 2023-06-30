using DrWatson

@quickactivate

using Dates
using TimeZones
using Bijections
using DataFrames
using DataFramesMeta

using CairoMakie

include(srcdir("process_doserates.jl"))
include(srcdir("read_datasheet.jl"))
include(srcdir("ensemble_verif.jl"))
include(srcdir("plots.jl"))

filtered_sensors = [
    "IMR/M03", 
    "IMR/M04", 
    "IMR/M15",
    "IMR/M02",
];

observations = remove_background(read_dose_rate_sensors())
# observations = @chain observations begin
#     @rsubset _ :longName in ["IMR/M03", "IMR/M04", "IMR/M15"]
#     @rsubset _ :stop >= DateTime("2019-05-15T15:20:00")
#     @rsubset _ :stop <= DateTime("2019-05-15T16:10:00")
# end

sims = Dict(
    "ENFO_BE_20190513T00_res=0.0001_timestep=10_we=1000.0" => astimezone(ZonedDateTime(2019,5,13,00,00,00, tz"UTC"), tz"Europe/Brussels"),
    "ENFO_BE_20190513T12_res=0.0001_timestep=10_we=1000.0" => astimezone(ZonedDateTime(2019,5,13,12,00,00, tz"UTC"), tz"Europe/Brussels"),
    "ENFO_BE_20190514T00_res=0.0001_timestep=10_we=1000.0" => astimezone(ZonedDateTime(2019,5,14,00,00,00, tz"UTC"), tz"Europe/Brussels"),
    "ENFO_BE_20190514T12_res=0.0001_timestep=10_we=1000.0" => astimezone(ZonedDateTime(2019,5,14,12,00,00, tz"UTC"), tz"Europe/Brussels"),
    "ENFO_BE_20190515T00_res=0.0001_timestep=10_we=1000.0" => astimezone(ZonedDateTime(2019,5,15,00,00,00, tz"UTC"), tz"Europe/Brussels"),
) |> Bijection
oper_sim = "FirstPuff_OPER_res=0.0001_timestep=10_we=1000.0"

ens_dose_rates = aggregate_sims(sims)
ens_dose_rates = filter_times_receptors(ens_dose_rates, filtered_sensors)

oper_dose_rates = filter_times_receptors(dose_rates_to_df(oper_sim), filtered_sensors)

by_fcstart_ens = combine(groupby(ens_dose_rates, [:time, :forecast_start, :receptorName]), 
    :H10 => mean => :sim_mean, 
    :H10 => median => :sim_median, 
    :H10 => std => :sim_std, 
    :H10 => var => :sim_var
)

# This show that the difference between the median and the mean is small.
hist(ustrip.(by_fcstart_ens.sim_mean .- by_fcstart_ens.sim_median))

ensemble_stats = combine(groupby(ens_dose_rates, [:time, :receptorName]), 
    :H10 => mean, 
    :H10 => median, 
    :H10 => std, 
    :H10 => var
)

oper = oper_dose_rates
ens = ens_dose_rates
obs = observations
fobs = @rsubset observations :stop in unique(ens.time)

f_spreads = plot_spreads_all_receptors(ens, oper, fobs)
save(plotsdir("ensembles_spreads.svg"), f_spreads)

# The mean must be the same regardless of when it is calculated
@assert all(combine(groupby(by_fcstart_ens, [:time, :receptorName]), :sim_mean => mean).sim_mean_mean .≈ ensemble_stats.:H10_mean)
# The median is different regardingof of when it is calculated
@assert any(combine(groupby(by_fcstart_ens, [:time, :receptorName]), :sim_median => median).sim_median_median .≈ ensemble_stats.H10_median) == false


mean_and_median_spread = sort(combine(groupby(by_fcstart_ens, :forecast_start), :sim_std => mean => :mean_spread, :sim_std => median => :median_spread), :forecast_start)

##
f_spread = Figure(; 
    # resolution = (1000, 500)
)
ax_spread = Axis(f_spread[1, 1],)
hist!(ax_spread, ustrip.(ensemble_stats.sim_std))
vlines!(ax_spread, ustrip(mean(ensemble_stats.sim_std)), label = "mean")
vlines!(ax_spread, ustrip(median(ensemble_stats.sim_std)), label = "median")
axislegend()
f_spread
##

joined_oper = innerjoin(oper_dose_rates, observations, on = [:time => :stop, :receptorName => :longName])

df = innerjoin(df, observations; on = [:time => :stop, :receptorName => :longName])
by_members = groupby(df, [:forecast_start, :receptorName, :time])
with_mean = transform(by_members, :H10 => mean)

@assert mean(by_members[1].H10) == (@chain with_mean begin
    @rsubset _ :receptorName == keys(by_members)[1].receptorName
    @rsubset _ :time == keys(by_members)[1].time
    @rsubset _ :forecast_start == keys(by_members)[1].forecast_start
end).H10_mean[1]

combine(groupby(df, []), :H10 => mean)

by_time = groupby(df, :time)

by_time_by_fcs = groupby(by_time[1], :forecast_start)

groupby(by_time_by_fcs[1], :receptorName)

# res = Dict()
# for (time, by_time) in pairs(groupby(df, :time))
#     for (fcs, by_fcs) in pairs(groupby(by_time, :forecast_start))
#         for (receptor, by_receptor) in pairs(groupby(by_fcs, :receptorName))
#             println(length(by_receptor.H10))
#             res[[time.time, fcs.forecast_start, receptor.receptorName]] = mean(by_receptor.H10)
#         end
#     end
# end

stats_by_sim = combine(groupby(df, [:time, :forecast_start, :receptorName]), :H10 => mean => :sim_mean, :H10 => std => :sim_std, :H10 => var => :sim_var)

# Statistics considering each forecast start time as members (250 members)
stats = combine(groupby(df, [:time, :receptorName]), :H10 => mean => :sim_mean, :H10 => std => :sim_std, :H10 => var => :sim_var)

groupby(stats_by_sim, :time)