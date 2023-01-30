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
        :Z1 => rel_params.height,
        :Z2 => rel_params.height,
        :MASS => rel_params.mass,
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

function command_dict(sim::SimParams)
    @unpack timestep, divsample, start, stop = sim
    timestep_sec = uconvert(u"s", timestep)
    time_params = Dict(
        :LOUTSTEP => timestep_sec,
        :LOUTAVER => timestep_sec,
        :LOUTSAMPLE => ustrip(timestep_sec) / divsample |> Int,
        :LSYNCTIME => ustrip(timestep_sec) / divsample |> Int,
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

function outgrid_dict(sim::SimParams)
    bbox = make_box(sim.release.location, sim.we, sim.ns)
    outgrid = Flexpart.area2outgrid(collect(bbox), sim.res)
    return merge(outgrid, Dict(:OUTHEIGHTS => join(ustrip.(uconvert.(u"m", sim.heights)), ",")))
end

function specie_dict(sim::SimParams; refspecie = 18)
    @unpack specie, specie = sim
    refspecie = "SPECIES/SPECIES_0$refspecie"
    selenium = FlexpartSim() do fpsim
        fpoptions = FlexpartOption(fpsim)
        deepcopy(fpoptions[refspecie])
    end
    selenium_params = selenium[:SPECIES_PARAMS][1]

    new_specie_params = Dict(
        :PSPECIES => "\"Se-75\"",
        :PDECAY => half_life(specie),
        :PDENSITY => density(specie),
        :PWEIGHTMOLAR => molar_mass(specie),
    )

    merge!(selenium_params, new_specie_params)
    fpoptions.options["SPECIES/SPECIES_050"] = selenium
    Flexpart.save(fpoptions)

end