using DrWatson
using Flexpart
using Flexpart.FlexpartOptions
using Dates
using Unitful
using Sckcen

const DEFAULT_RELEASE_START = DateTime(2019, 5, 15, 0)
const DEFAULT_RELEASE_STOP = DateTime(2019, 5, 15, 3)
const DEFAULT_SIM_START = DateTime(2019, 5, 15, 0)
const DEFAULT_SIM_STOP = DateTime(2019, 5, 15, 23)

_time_format(date::DateTime) = Dates.format(date, "HHMMSS")
_date_format(date::DateTime) = Dates.format(date, "yyyymmdd")
_strip(v::String) = v
_strip(v) = ustrip(v)
_stripdict(dict) = Dict(k => _strip(v) for (k, v) in dict)

Base.string(q::Unitful.Quantity) = string(ustrip(q))

function build_source_terms(elem::Symbol, source_start, source_windows, source_rates)
    acc = source_start
    res = SourceTerm[]
    for (window, rate) in zip(source_windows, source_rates)
        right_interval = acc + window
        push!(res, SourceTerm(elem, acc, right_interval, rate))
        acc = acc + window
    end
    return res
end

Base.@kwdef mutable struct ReleaseParams
    location::ReleasePoint = ReleasePoint()
    start::DateTime = DEFAULT_RELEASE_START
    stop::DateTime = DEFAULT_RELEASE_STOP
    nparts::Int = Flexpart.MAX_PARTICLES
    mass::Unitful.Mass = 1u"kg"
    height::Unitful.Length = 60.0u"m"
end
DrWatson.allaccess(::ReleaseParams) = (:start, :stop, :mass, :height)
DrWatson.default_allowed(::ReleaseParams) = (Real, TimeType, Unitful.Quantity)

function build_releases(sourceterms::Vector{<:SourceTerm}, height = 60.0u"m")
    all_masses = get_mass.(Activity.(sourceterms))
    total_mass = sum(all_masses)
    weights = all_masses ./ total_mass
    particles_by_release = Int.(floor.(weights .* Flexpart.MAX_PARTICLES))
    map(zip(sourceterms, particles_by_release, all_masses)) do (sourceterm, nparts, mass)
        ReleaseParams(
            start = sourceterm.duration.first,
            stop = sourceterm.duration.last,
            nparts = nparts,
            mass = mass,
            height = height
        )
    end
end

Base.@kwdef mutable struct SimParams
    name::String
    input::String
    start::DateTime = DEFAULT_SIM_START
    stop::DateTime = DEFAULT_SIM_STOP
    releases::Vector{<:ReleaseParams} = [ReleaseParams()]
    we::Unitful.Length = 5000.0u"m"
    ns::Unitful.Length = 5000.0u"m"
    res = 0.01
    heights::Vector{<:Unitful.Length} = [100.0u"m"]
    timestep::Unitful.Time = 30u"minute"
    divsample::Int = 4
    command::Dict = Dict(
        :CBLFLAG => 0,
        :CTL => 10,
        :IFINE => 10,
    )
end

function SimParams(name::String, input::String; kw...)
    inputpath = datadir("extractions", input, "output")
    isdir(inputpath) || error("input dir not existing")
    isempty(readdir(inputpath)) && error("no flexpart input files in the input directory")
    SimParams(; name, input = inputpath, kw...)
end
DrWatson.allaccess(::SimParams) = (:res, :timestep)
DrWatson.default_prefix(sim::SimParams) = "$(sim.name)"
DrWatson.default_allowed(::SimParams) = (Real, TimeType, Unitful.Quantity)
simdir(sim::SimParams) = datadir("sims", savename(sim))
simdir(simname::String) = datadir("sims", simname)
simpathnames(sim) = joinpath(simdir(sim), "pathnames")

function Flexpart.create(sim::SimParams; simtype = Deterministic)
    sim_dir = simdir(sim)
    mkpath(sim_dir)
    fpsim = Flexpart.create(sim_dir; simtype)
    fpsim[:input] = sim.input
    Flexpart.save(fpsim)
    return fpsim
end

Flexpart.FlexpartSim(sim::SimParams) = FlexpartSim(simpathnames(sim))

FlexpartOptions.FlexpartOption(sim::SimParams) = FlexpartOption(FlexpartSim(sim))

iscreated(sim::SimParams) = isdir(simdir(sim))