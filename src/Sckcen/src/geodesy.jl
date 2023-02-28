
# ? We use euclidean distance here, which is ok for small distances. It might be better to implement it with PROJ to have more precise values,
# ? but is it worth it ?
"""
    distance(point1::T, point2::T) where T <: Tuple
Calculate the euclidean distance between two points given as a Tuple with field `lat`, `lon` and `alt`. The ellipsoid is considered being WGS84.
"""
function distance(point1::T, point2::T) where T <: NamedTuple
    point1lla = LLA(; point1...)
    point2lla = LLA(; point2...)
    euclidean_distance(point1lla, point2lla)
end

"""
    distance(point1::T, point2::T) where T <: AbtractVector
Calculate the euclidean distance between two points given as a vector such that `[lon, lat, alt]``
"""
function distance(point1::T, point2::T) where T <: AbstractVector
    # I prefer to work with [lon, lat, alt] by default, but Geodesy prefers [lat, lon, alt]
    point1lla = LLA(point1[2], point1[1], point1[3])
    point2lla = LLA(point2[2], point2[1], point2[3])
    euclidean_distance(point1lla, point2lla)
end