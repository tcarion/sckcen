using DrWatson
using Flexpart
using Unitful
using Sckcen
using Logging
using TimeZones

include(srcdir("fp_prepare.jl"))

## SCRIPTS INPUTS
FORCE_CREATE = false
element_id = :Se75
# run_name = "FirstPuff_ELDA"
run_name = "ENFO_BE_20190515T00"

res = 0.0005
res = 0.0001
### Source term definition
source_start = DateTime(2019,5,15,15,10)
stop_sim = DateTime(2019, 5, 15, 17)
# stop_sim = DateTime("2023-03-29T17:00:00")
# source_start = DateTime("2023-03-29T15:10:00")
source_windows = Minute.(fill(10, 6))
rates_windows = [9.1, 8.6, 4.1, 1.6, 1.0, 0.9] .* u"MBq/s"

sourceterms = build_source_terms(element_id, source_start, source_windows, rates_windows)

input_dir = "ENFO/2019051500/PF"

sim = SimParams(run_name, input_dir;
    res = res,
    timestep = 10u"minute",
    divsample = 2,
    ctl = 5,
    start = source_start,
    stop =  stop_sim,
    we = 1000.0u"m",
    ns = 1000.0u"m",
    heights = range(0, 200, 21) .* u"m",
    releases = build_releases(sourceterms),
)


fpsim = if FORCE_CREATE
    rm(simdir(sim); recursive = true)
    Flexpart.create(sim; simtype = Ensemble)
else
    iscreated(sim) ? FlexpartSim{Ensemble}(sim) : Flexpart.create(sim; simtype = Ensemble)
end
    
fpoptions = FlexpartOption(sim)

add_releases!(fpoptions, sim)
merge!(fpoptions["COMMAND"][:COMMAND], command_dict(sim))
merge!(fpoptions["OUTGRID"][:OUTGRID], outgrid_dict(sim; digits = 4))
fpoptions.options["SPECIES/SPECIES_050"] = specie_dict(element_id)
fpoptions["RELEASES"][:RELEASES_CTRL][:SPECNUM_REL] = 50

Flexpart.save(fpoptions)


avs = Available(fpsim)

# Add 1 hour because of time offset
for input in avs
    input.time = DateTime(astimezone(ZonedDateTime(input.time, tz"UTC"), tz"Europe/Brussels"))
end

saveddir = Flexpart.save(avs)

@info "The flexpart parameters have been set @ $(saveddir)"