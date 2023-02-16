using DrWatson
using Rasters
using ColorTypes: N0f8, RGB
using Geodesy

include(srcdir("parameters.jl"))

const ORIGIN = LLA(RELLAT, RELLON, RELHEIGHT)
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
