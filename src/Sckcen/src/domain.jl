const RELLAT = 51.21507
const RELLON = 5.09597

const WE_LENGTH = 4000.
const NS_LENGTH = 4000.

Base.@kwdef mutable struct ReleasePoint{T<:AbstractFloat}
    lon::T = RELLON
    lat::T = RELLAT
end

mutable struct BBox{T<:AbstractFloat}
    upper::T
    left::T
    lower::T
    right::T
end
Base.collect(bbox::BBox) = [bbox.upper, bbox.left, bbox.lower, bbox.right]

Geodesy.LLA(rp::ReleasePoint) = LLA(rp.lat, rp.lon)

function make_box(rp::ReleasePoint, we_length, ns_length)
    origin_lla = LLA(rp)
    trans = LLAfromENU(origin_lla, wgs84)
    west_side = (-we_length / 2, 0.)
    east_side = (we_length / 2, 0.)
    north_side = (0., ns_length / 2)
    south_side = (0., -ns_length / 2)
    west_side_lla = trans(ENU(west_side...))
    east_side_lla = trans(ENU(east_side...))
    north_side_lla = trans(ENU(north_side...))
    south_side_lla = trans(ENU(south_side...))
    BBox(
        north_side_lla.lat,
        west_side_lla.lon,
        south_side_lla.lat,
        east_side_lla.lon
    )
end

make_box(rp::ReleasePoint = ReleasePoint(), we::Unitful.Length = WE_LENGTH*m, ns::Unitful.Length = NS_LENGTH*m) = 
    make_box(rp, uconvert(m, we) |> ustrip, uconvert(m, ns) |> ustrip)

function round_area(area::AbstractVector)
    return [ceil(area[1]), floor(area[2]), floor(area[3]), ceil(area[4])]
end

round_area(bbox::BBox) = round_area(collect(bbox))