using DrWatson
using DataFrames
using StatsBase
using StatsBase: ordinalrank
using DataFramesMeta
using Unitful
using DimensionalData
using DimensionalData: dims as ddims, metadata as ddmetadata
using Geodesy 

include(srcdir("read_datasheet.jl"))
include(srcdir("parameters.jl"))
include(srcdir("projections.jl"))

dose_rate_savename(simname) = datadir("sims", simname, "dose_rates.jld2")
dose_rate_process_savename(simname) = datadir("sims", simname, "dose_rates_process.jld2")
dose_rate_file(simname::String) = datadir("sims", simname, "dose_rates.jld2")

const DOSE_RATES_SAVENAME = "dose_rates"
const DOSE_RATES_FILENAME = "dose_rates.jld2"

# should be depracated
ensemble_dose_rates_to_df(simname::AbstractString) = ensemble_dose_rates_to_df(load(dose_rate_savename(simname)))

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

function dose_rates_to_df(dose_rates_da) 
    df = rename!(DataFrame(dose_rates_da), [:Ti, :sensor] .=> [:time, :receptorName])
    df.simname .= get(ddmetadata(dose_rates_da), "simname", "")
    df.simtype .= get(ddmetadata(dose_rates_da), "simtype", "")
    df.isensemble .= get(ddmetadata(dose_rates_da), "ensemble", false)
    return df
end

dose_rates_to_df(simname::AbstractString) = dose_rates_to_df(load(dose_rate_savename(simname))[DOSE_RATES_SAVENAME])

function join_dose_rates_sensors(simresults::DataFrame, sensors::DataFrame)
    newsens = rename(sensors, [:longName, :stop, :value] .=> [:receptorName, :time, :H10])
    newsens.simtype .= "measure"
    newsens.isensemble .= false
    return vcat(simresults, newsens; cols = :union)
end
join_dose_rates_sensors(simresults::DataFrame) = join_dose_rates_sensors(simresults, remove_background(read_dose_rate_sensors()))

merge_dose_rates_results(dfs::Vector{<:DataFrame}) = vcat(dfs...; cols=:union)
merge_dose_rates_results(names_or_das) = merge_dose_rates_results(dose_rates_to_df.(names_or_das))

function to_df_and_save(simname::AbstractString)
    fname = dose_rate_savename(simname)
    jldopen(fname, "a+") do f
        if !haskey(f, "df")
            df = ensemble_dose_rates_to_df(simname)
            f["df"] = df
            @info "Dose rates converted to DataFrame in file $fname"
        end
        return f["df"]
    end
end
"""
    mean_and_std(dose_rate_df::DataFrame)
Compute the mean and standard deviation of the members for each time steps.
"""
mean_and_std(dose_rate_df::DataFrame) = combine(groupby(dose_rate_df, [:receptorName, :times]), :H10 => mean, :D => mean, :D => std, :H10 => std)

mean_and_std(simname::AbstractString) = mean_and_std(ensemble_dose_rates_to_df(simname))

function compute_dose_rates(concentration, sensor_numbers, sensors_dose_rates, nuclide_data = read_lara_file("Se-75"), rho = 0.001161u"g/cm^3"; relloc = [RELLON, RELLAT])
    times = ddims(concentration, Ti) |> collect

    raster_crs = crs(concentration)

    trans = ENUfromLLA(LLA(lat = relloc[2], lon = relloc[1]), wgs84)
    dose_rates = map(sensor_numbers) do sensor_number
        @info "Sensor number: $sensor_number"
        location_receptor = get_sensor_location(sensors_dose_rates, sensor_number)

        receptor_lla = LLA(; location_receptor...)
        receptor = if raster_crs == EPSG(4326)
            receptor_lla
        else
            trans(receptor_lla)
        end
    
        D, H10 = time_resolved_dosimetry(concentration, receptor, nuclide_data, rho)
    
        dimt = Ti(times)
    
        stack = DimStack((
            D = DimArray(D, dimt),
            H10 = DimArray(H10, dimt),
        ))
        return stack
    end

    sensor_names = _name_from_number.(sensor_numbers)

    dose_rates_da = cat(dose_rates..., dims = Dim{:sensor}(sensor_names))

    return dose_rates_da
end

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