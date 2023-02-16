using DrWatson
using Flexpart
using Flexpart.FlexpartOptions
using Flexpart.FlexpartInputs
using Unitful
using Sckcen
using Logging

include(srcdir("fp_prepare.jl"))

## SCRIPTS INPUTS
FORCE_CREATE = false
element_id = :Se75
run_name = "FirstPuff_OPER"

### Source term definition
source_start = DateTime(2019,5,15,15,10)
source_windows = Minute.(fill(10, 6))
rates_windows = [9.1, 8.6, 4.1, 1.6, 1.0, 0.9] .* u"MBq/s"

sourceterms = build_source_terms(element_id, source_start, source_windows, rates_windows)

input_dir = "OPER_20190515"

sim = SimParams(run_name, input_dir;
    res = 0.0001,
    timestep = 10u"minute",
    divsample = 2,
    ctl = 5,
    start = source_start,
    stop =  DateTime(2019, 5, 15, 17),
    we = 5000.0u"m",
    ns = 5000.0u"m",
    heights = range(0, 200, 21) .* u"m",
    releases = build_releases(sourceterms),
)

fpsim = if FORCE_CREATE
    rm(simdir(sim); recursive = true)
    Flexpart.create(sim)
else
    iscreated(sim) ? FlexpartSim(sim) : Flexpart.create(sim)
end
    
fpoptions = FlexpartOption(sim)

add_releases!(fpoptions, sim)
merge!(fpoptions["COMMAND"][:COMMAND], command_dict(sim))
merge!(fpoptions["OUTGRID"][:OUTGRID], outgrid_dict(sim; digits = 4))
fpoptions.options["SPECIES/SPECIES_050"] = specie_dict(element_id)
fpoptions["RELEASES"][:RELEASES_CTRL][:SPECNUM_REL] = 50

Flexpart.save(fpoptions)


avs = Available(fpsim)

# Change the AVAILABLE for correcting the timezone difference. Should be easier to do that, will need to reimplement Flexpart...
input_files = map(avs) do input
    typeof(input)(input.time + Dates.Hour(1), input.filename, input.dirpath)
end
avs_tz = Available(avs.header, avs.path, input_files)

saveddir = Flexpart.save(avs_tz)

@info "The flexpart parameters have been set @ $(saveddir)"