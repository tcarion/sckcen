using DrWatson
using DataFrames
using StatsBase
using StatsBase: ordinalrank
using DataFramesMeta

include(srcdir("read_datasheet.jl"))

dose_rate_savename(simname) = datadir("sims", simname, "dose_rates.jld2")
dose_rate_process_savename(simname) = datadir("sims", simname, "dose_rates_process.jld2")

function ensemble_dose_rates_to_df(dose_rates_results)
    each_sensor = map(collect(pairs(dose_rates_results))) do (sensor_name, results)
        dfs = [DataFrame(
            times = result.times, 
            D = result.D, 
            H10 = result.H10,
            member = fill(result.imember, length(result.H10))
        ) for result in results]
    
        df = vcat(dfs...)
        df.receptorName .= sensor_name
        return df
    end
    vcat(each_sensor...)
end

ensemble_dose_rates_to_df(simname::AbstractString) = ensemble_dose_rates_to_df(load(dose_rate_savename(simname)))

"""
    mean_and_std(dose_rate_df::DataFrame)
Compute the mean and standard deviation of the members for each time steps.
"""
mean_and_std(dose_rate_df::DataFrame) = combine(groupby(dose_rate_df, [:receptorName, :times]), :H10 => mean, :D => mean, :D => std, :H10 => std)

mean_and_std(simname::AbstractString) = mean_and_std(ensemble_dose_rates_to_df(simname))

"""
    talagrand(dose_rates_results)::Vector{Int}
Compute the ranks of every observation according to the ensemble results. This can be used to draw a Telegrand histogram (rank-histogram).

## Reference
https://www.statisticshowto.com/rank-histogram/
"""
function talagrand(dose_rates_df)::Vector{Int}
    sensors_dose_rates = read_dose_rate_sensors()
    sensors_dose_rates = remove_background(sensors_dose_rates)
    sensors_dose_rates.member .= -1 # We flag the member to -1 to note it is observations

    sensors_formated = @chain sensors_dose_rates begin
        rename(_, [:longName, :value, :stop] .=> [:receptorName, :H10, :times])
        @rsubset :times <= maximum(dose_rates_df.times) && :times >= minimum(dose_rates_df.times)
        @rsubset :receptorName in unique(dose_rates_df.receptorName)
        @select(:receptorName, :times, :H10, :member)
    end
    append = vcat(select(dose_rates_df, Not(:D)), sensors_formated)

    by_obs = groupby(append, [:times, :receptorName])

    ranked = transform(by_obs, :H10 => (x -> ordinalrank(x)) => :rank)

    obs_rank = @rsubset ranked :member == -1
    return obs_rank.rank
end