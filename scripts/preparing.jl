using DrWatson
using Flexpart
using Flexpart.FlexpartOptions
using Flexpart.FlexpartInputs

include(srcdir("fp_prepare.jl"))

FORCE_CREATE = false

input_dir = "OPER_20190515"

sim = SimParams(input_dir;
    res = 0.001,
    stop =  DateTime(2019, 5, 15, 23)
)

fpsim = if FORCE_CREATE
    rm(simdir(sim); recursive = true)
    Flexpart.create(sim)
else
    iscreated(sim) ? FlexpartSim(sim) : Flexpart.create(sim)
end
    
fpoptions = FlexpartOption(sim)

merge!(fpoptions["RELEASES"][:RELEASE][1], release_dict(sim.release))
merge!(fpoptions["COMMAND"][:COMMAND], command_dict(sim))
merge!(fpoptions["OUTGRID"][:OUTGRID], outgrid_dict(sim))
fpoptions.options["SPECIES/SPECIES_050"] = specie_dict(sim)
fpoptions["RELEASES"][:RELEASES_CTRL][:SPECNUM_REL] = 50

Flexpart.save(fpoptions)


avs = Available(fpsim)
Flexpart.save(avs)
