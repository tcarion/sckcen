using DrWatson
@quickactivate

using JLD2

include(srcdir("montecarlo.jl"))

simname = "OPER_PG_LOGNORM_AZIMUTH"

puffs = load(mc_concentrationfile(simname))[MC_GAUSSIAN_SAVENAME]

