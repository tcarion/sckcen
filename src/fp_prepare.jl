using DrWatson
using Flexpart
using Flexpart.FlexpartOptions
using Sckcen
using Unitful
using Dates

include("fp_utils.jl")

# Base.convert()

function release_dict(rel_params::ReleaseParams)
    @unpack start, stop = rel_params
    @unpack lon, lat  = rel_params.location
    rel_dict = Dict(
        :Z1 => uconvert(u"m", rel_params.height),
        :Z2 => uconvert(u"m", rel_params.height),
        :MASS => uconvert(u"kg", round(typeof(1.0u"ng"), rel_params.mass)),
        :PARTS => rel_params.nparts,
        :IDATE1 => _date_format(start),
        :ITIME1 => _time_format(start),
        :IDATE2 => _date_format(stop),
        :ITIME2 => _time_format(stop),
        :LAT1 => lat,
        :LAT2 => lat,
        :LON1 => lon,
        :LON2 => lon,
    )
    _stripdict(rel_dict)
end

function add_releases!(fpoptions::FlexpartOption, sim::SimParams)
    default_releases = _get_default_option("RELEASES")[:RELEASE]
    copied_release = deepcopy(default_releases[1])

    option_releases = fpoptions["RELEASES"][:RELEASE]
    while !isempty(option_releases)
        pop!(option_releases)
    end

    for rel_param in sim.releases
        newrel = merge!(copied_release, release_dict(rel_param))
        push!(option_releases, deepcopy(newrel))
    end
end

function command_dict(sim::SimParams)
    @unpack timestep, divsample, start, stop = sim
    timestep_sec = uconvert(u"s", timestep)
    lat = sim.releases[1].location.lat
    δx = sim.res * 111320 * cosd(lat)
    tstep = Int(max(round(δx / 20., sigdigits=1), 1))

    time_params = Dict(
        :LOUTSTEP => timestep_sec,
        :LOUTAVER => timestep_sec,
        :LOUTSAMPLE => tstep,
        :LSYNCTIME => tstep,
        :CTL => sim.ctl,
        :IBDATE => Dates.format(start, "yyyymmdd"),
        :IBTIME => Dates.format(start, "HHMMSS"),
        :IEDATE => Dates.format(stop, "yyyymmdd"),
        :IETIME => Dates.format(stop, "HHMMSS"),
    )

    others = Dict(
        :IOUT => 9
    )
    cmd_dict = merge(time_params, sim.command, others)
    _stripdict(cmd_dict)
end

function outgrid_dict(sim::SimParams; digits = nothing)
    bbox = make_box(sim.releases[1].location, sim.we, sim.ns)
    area = isnothing(digits) ? collect(bbox) : round_area(bbox; digits)
    outgrid = Flexpart.area2outgrid(area, sim.res)
    return merge(outgrid, Dict(:OUTHEIGHTS => join(ustrip.(uconvert.(u"m", sim.heights)), ",")))
end

function specie_dict(elem_id::Symbol; refspecie_num = 18)
    specie = Element(elem_id)
    refspecie = "SPECIES/SPECIES_0$refspecie_num"
    selenium = FlexpartSim() do fpsim
        fpoptions = FlexpartOption(fpsim)
        deepcopy(fpoptions[refspecie])
    end
    selenium_params = selenium[:SPECIES_PARAMS][1]

    new_specie_params = Dict(
        :PSPECIES => "\"Se-75\"",
        :PDECAY => half_life(specie),
        :PDENSITY => Sckcen.density(specie),
        :PWEIGHTMOLAR => molar_mass(specie),
    )

    merge!(selenium_params, new_specie_params)
    return selenium
end

_get_default_option(option) = FlexpartSim() do fpsim
    fpoptions = FlexpartOption(fpsim)
    deepcopy(fpoptions[option])
end