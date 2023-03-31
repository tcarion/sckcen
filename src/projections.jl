using DrWatson
using Rasters
using ColorTypes: N0f8, RGB
using Geodesy
using ArchGDAL
using GeoInterface

const AG = ArchGDAL
const GI = GeoInterface

include(srcdir("parameters.jl"))

const ORIGIN = LLA(RELLAT, RELLON, 0.)
const trans_enu = ENUfromLLA(ORIGIN, wgs84)

# source_proj = ProjString("+proj=longlat +datum=WGS84 +no_defs")
source_proj = EPSG(4326)
# target_proj = ProjString("+proj=utm +zone=31 +datum=WGS84 +units=m +no_defs") # EPSG:32231
target_proj = EPSG(31370)

load_map(map_name) = Raster(datadir("maps", map_name))

"""
    map2rgb(map)
Convert the 3 bands Raster `map` into a 2-D Raster with the element value as RGB's.
"""
function map2rgb(mmap)
    band1, band2, band3 = [reinterpret.(N0f8, mmap[Band = i]) for i in 1:3]
    RGB.([band1, band2, band3]...)
end

function resample2map(raster, mmap; method = :max) 
    # resol = round(step(dims(mmap, :X)), sigdigits = 1)
    Rasters.resample(raster; to = mmap, method)
end

function get_center(mmap)
    x1, xlast = extrema(dims(mmap, X))
    y1, ylast = extrema(dims(mmap, Y))

    x1 + (xlast - x1) / 2, y1 + (ylast - y1) / 2
end

"""
    lla_to_lambert(lla_points; shift = [0, 0])
Takes a tuple like object with `lat` and `lon` fields and project the coordinates with the
Lambert projection. Return a tuple with `X` and `Y` fields representing the coordinates in Lambert.
Optionnaly shift the coordinates according to `shift`
"""
function lla_to_lambert(lla_points; shift = [0, 0])
    apoints = AG.createpoint.(zip(lla_points.lat, lla_points.lon))
    lpoints = AG.reproject(apoints, source_proj, target_proj)
    (; zip(GI.coordnames(lpoints[1]), (GI.getcoord.(lpoints, 1) .- shift[1], GI.getcoord.(lpoints, 2) .- shift[2]))...)
end

lla_to_enu(object) = trans_enu(LLA(; lat = object.lat, lon = object.lon))