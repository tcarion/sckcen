using GRIB
using GRIBDatasets
using DimensionalData
include(srcdir("fp_utils.jl"))

const ISA_MSL_PRESSURE = 101325.

struct InputArrays
    ds::GRIBDataset
    lons
    lats
    heights
    saved
end

function InputArrays(filepath::String; tosave = ("u", "v", "t"))
    ds = GRIBDataset(filepath)

    lons = X(ds["longitude"])
    lats = Y(ds["latitude"])
    heights = Z(level_heights(filepath))
    dims = (lons, lats, heights)

    saved = map(tosave) do var
        _todimarray(ds, var, dims)
    end

    saved = (; zip(Symbol.(tosave), saved)...)
    InputArrays(ds, lons, lats, heights, saved)
end

_todimarray(ds, var, dims) = DimArray(ds[var][:,:,1,end:-1:1], dims)
Base.getindex(o::InputArrays, var::Symbol) = getindex(o.saved, var)
Base.getindex(o::InputArrays, var::String) = getindex(o.ds, var)

Base.show(io::IO, ::MIME"text/plain", o::InputArrays) = print(io, "Input at $(o.ds.index.grib_path)")

struct BoundingInputs
    t1::InputArrays
    t2::InputArrays
end

function Base.show(io::IO, mime::MIME"text/plain", o::BoundingInputs) 
    println(io, "Input1 at $(o.t1.ds.index.grib_path)")
    print(io, "Input2 at $(o.t2.ds.index.grib_path)")
end


function BoundingInputs(inputdir::String, date::DateTime)
    infiles = bound_input_files(inputdir, date)
    BoundingInputs(InputArrays(infiles[1]), InputArrays(infiles[2]))
end

function nearest_input(date, inputs)
    diff = map(inputs) do input
        abs(input.time - date)
    end
    inputs[argmin(diff)]    
end

valid_time(input::InputArrays) = GRIBDatasets.DEFAULT_EPOCH .+ Second.(collect(input.ds["valid_time"])) |> first
time_bounds(bound::BoundingInputs) = (valid_time(bound.t1), valid_time(bound.t2))

function linear_interp(bound::BoundingInputs, var::Symbol, time; coords = (RELLON, RELLAT, RELHEIGHT))
    t1, t2 = time_bounds(bound)
    v1 = nearest_interp(bound.t1, var; coords)
    v2 = nearest_interp(bound.t2, var; coords)

    return (time  - t1) / (t2 - t1) * (v2 - v1) + v1
end

function nearest_interp(input::InputArrays, var::Symbol; coords = (RELLON, RELLAT, RELHEIGHT))
    x, y, z = coords
    return input[var][X(Near(x)), Y(Near(y)), Z(Near(z))]
end

function process_wind(un, vn)
    wind_speed = Base.hypot(un, vn)

    wind_azimuth = 90. - atand(vn, un)

    wind_speed, wind_azimuth
end
process_wind(meteo::NamedTuple) = process_wind(meteo.u, meteo.v)

function extract_meteo_ecmwf(inputdir::String, times::Vector{<:DateTime})
    bounding_inputs = BoundingInputs(inputdir, first(times))
    t1, t2 = time_bounds(bounding_inputs)
    res = []
    for time in times
        if time >= t2
            bounding_inputs = BoundingInputs(inputdir,time)
            t1, t2 = time_bounds(bounding_inputs)
        end

        u = linear_interp(bounding_inputs, :u, time)
        v = linear_interp(bounding_inputs, :v, time)
        t = linear_interp(bounding_inputs, :t, time)

        push!(res, (; u, v, t))
    end
    return res
end

function grib_area(file::String) :: Vector{<:Float32}
    GribFile(file) do reader
        m = Message(reader)
        lons, lats = data(m)
        min_lon = minimum(lons)
        max_lon = maximum(lons)
        if min_lon > 180 || max_lon > 180
            min_lon -= 360
            max_lon -= 360
        end
        if min_lon < -180 || max_lon < -180
            min_lon += 360
            max_lon += 360
        end
        return convert.(Float32, [maximum(lats), min_lon, minimum(lats), max_lon])
    end
end

function grib_resolution(file::String)
    GribFile(file) do reader
        m = Message(reader)
        lons, lats = data(m)
        difflon = lons[2, 1] - lons[1, 1] 
        difflat = lats[1, 1] - lats[1, 2]
        round(difflon, digits = 5), round(difflat, digits = 5)
    end
end

function get_key_values(file::String, key::String)
    key_values = Vector()
    GribFile(file) do reader
        for msg in reader
            push!(key_values, string(msg[key]))
        end
    end
    return unique(key_values)
end

function get_keys(file::String)::Vector{String}
    keylist = Vector{String}()
    GribFile(file) do reader
        for msg in reader
            for key in keys(msg)
                push!(keylist, key)
            end
        end
    end
    keylist |> unique
end

"""
    read_levels_coefs(file::String)
Read the A_{k+1/2} and B_{k+1/2}, the model level coefficients at the half levels, from the grib `file` by looking at the first hybrid level.
"""
function read_levels_coefs(file::String)
    coefs = Index(file, "typeOfLevel") do index
        # Find a message with hybrid levels
        select!(index, "typeOfLevel", "hybrid")
        # Get the coefficients for vertical level transformation
        Message(index)["pv"]
    end

    nlevel = Int(length(coefs) / 2 - 1)
    coefs = reshape(coefs, (nlevel+1, 2))

    # We want the lower border of the model level to be at the start of the vector
    ahs = reverse(coefs[:,1])
    bhs = reverse(coefs[:,2])
    return ahs, bhs
end

half_level_pressure(akh, bkh, ps) = akh + bkh * ps

function full_level_pressures(ahs, bhs, ps = ISA_MSL_PRESSURE)
    phs = half_level_pressure.(ahs, bhs, ps)
    0.5*(phs[2:end] + phs[1:end-1])
end

function level_heights(file::String, ps = ISA_MSL_PRESSURE)
    ahs, bhs = read_levels_coefs(file)
    phs = half_level_pressure.(ahs, bhs, ps)
    full_press = 0.5*(phs[2:end] + phs[1:end-1]) 
    pressure_to_height.(full_press)
end

"""
    pressure_to_height(p; kw...)
Give the geometric height [m] given the atmospheric pressure, approximating the temperature decreasing linearly with height. By default, the International Standard Atmosphere is considered. The keyword arguments are:
    - p0: the MSL pressure
    - T0: the MSL temperature
    - λ: the lapse rate.
"""
pressure_to_height(p; p0 = ISA_MSL_PRESSURE, T0 = 288.15, λ = 0.0065) = T0 / λ * (1 - (p / p0)^(8.31 * λ / (29e-3 * 9.81)))