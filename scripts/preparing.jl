using DrWatson
using Flexpart
using Flexpart.FlexpartOptions
using Flexpart.FlexpartInputs
using Unitful
using Sckcen

include(srcdir("fp_prepare.jl"))

## SCRIPTS INPUTS
FORCE_CREATE = false
element_id = :Se75
run_name = "FirstPuff_OPER"

### Source term definition
source_start = DateTime(2019,5,15,15,20)
source_windows = Minute.(fill(10, 6))
rates_windows = [9.1, 8.6, 4.1, 1.6, 1.0, 0.9] .* u"MBq/s"

sourceterms = build_source_terms(element_id, source_start, source_windows, rates_windows)

input_dir = "OPER_20190515"

sim = SimParams(run_name, input_dir;
    res = 0.0005,
    start = source_start,
    stop =  DateTime(2019, 5, 15, 23),
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
merge!(fpoptions["OUTGRID"][:OUTGRID], outgrid_dict(sim))
fpoptions.options["SPECIES/SPECIES_050"] = specie_dict(element_id)
fpoptions["RELEASES"][:RELEASES_CTRL][:SPECNUM_REL] = 50

Flexpart.save(fpoptions)


avs = Available(fpsim)
Flexpart.save(avs)
