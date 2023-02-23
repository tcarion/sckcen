using DrWatson
using XLSX
using Dates
using DataFrames
using DataFrames: subset
using Unitful
using Statistics

const DEFAULT_DATASHEET_PATH = datadir("measures", "zenodo-datasheet.xlsx")

function read_dose_rate_sensors(filepath = DEFAULT_DATASHEET_PATH)
    sheetname = "Dose rate"
    firstrow=3
    sheet = XLSX.readxlsx(filepath)[sheetname]
    collabels = [
        :locationID, :longName, :start, :stop, :lat, :lon, :value
    ]

    data = DataFrame(XLSX.gettable(sheet;
        first_row=firstrow,
        column_labels=collabels,
        header = false,
        infer_eltypes = true
    ))

    data.value = Float64.(data.value) * u"nSv/hr"
    data.start = DateTime.(data.start)
    data.stop = DateTime.(data.stop)
    return data
end


filter_sensor(data, sensor_name::AbstractString) = subset(data, :longName => x -> occursin.(sensor_name, x))
filter_sensor(data, sensor_number::Int) = filter_sensor(data, _name_from_number(sensor_number))


get_first_from_name(data, sensor_name::AbstractString) = filter(:longName => ==(sensor_name), data) |> first
get_first_from_name(data, sensor_number::Int) = get_first_from_name(data, _name_from_number(sensor_number))

function get_sensor_location(data, sensor_number)
    sensor = filter_sensor(data, sensor_number)
    return (
        lat = sensor.lat[1],
        lon = sensor.lon[1],
        alt = 1.
    )
end

function calc_background(
    data, 
    time_window = (DateTime(2019,5,15,12), DateTime(2019,5,15,15))
    )

    windowed = isnothing(time_window) ? data : filter(row -> row.start >= time_window[1] && row.stop <= time_window[2], data)
    # select(groupby(data, :longName), :value => mean)
    # returns
#     1440×2 DataFrame
#     Row │ longName  value_mean        
#         │ String    Quantity…         
#   ──────┼─────────────────────────────
#       1 │ IMR/M01   105.035 nSv hr^-1
#       2 │ IMR/M02   97.4465 nSv hr^-1
#       3 │ IMR/M03   84.8431 nSv hr^-1
#     ⋮   │    ⋮              ⋮
#    1438 │ IMR/M14   80.9576 nSv hr^-1
#    1439 │ IMR/M15   77.6757 nSv hr^-1
#    1440 │ IMR/M00   59.5111 nSv hr^-1
#                      1434 rows omitted
    #while
    return combine(groupby(windowed, :longName), :value => mean, :value => std)
    # returns
#     10×2 DataFrame
#     Row │ longName  value_mean        
#         │ String    Quantity…         
#    ─────┼─────────────────────────────
#       1 │ IMR/M01   105.035 nSv hr^-1
#       2 │ IMR/M02   97.4465 nSv hr^-1
#       3 │ IMR/M03   84.8431 nSv hr^-1
#       4 │ IMR/M04   72.0354 nSv hr^-1
#       5 │ IMR/M07   67.2694 nSv hr^-1
#       6 │ IMR/M08   80.5569 nSv hr^-1
#       7 │ IMR/M12   74.0833 nSv hr^-1
#       8 │ IMR/M14   80.9576 nSv hr^-1
#       9 │ IMR/M15   77.6757 nSv hr^-1
#      10 │ IMR/M00   59.5111 nSv hr^-1

end

function _name_from_number(sensor_number)
    strsn = string(sensor_number)
    strsn = length(strsn) == 1 ? "0$strsn" : strsn
    return "IMR/M$strsn"
end

dose_rate_savename(simname) = datadir("sims", simname, "dose_rates.jld2")

MEASURES_SAVENAME = datadir("measures", "measures.jld2")

read_background_stats() = load(MEASURES_SAVENAME, "background_stats")