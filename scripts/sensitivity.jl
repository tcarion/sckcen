using DrWatson
@quickactivate

using JLD2

include(srcdir("montecarlo.jl"))
include(srcdir("gaussian.jl"))
include(srcdir("parameters.jl"))
include(srcdir("gributils.jl"))


azimuth_sample = logn_sample(242, 10)

simname = "OPER_PG_LOGNORM_AZIMUTH"
mkpath(mc_gaussiandir(simname))
relstart = DateTime(RELSTART)

inputdir = "/home/tcarion/projects/sckcen/data/extractions/OPER_20190515/output"

times = RELEASE_TIMES

@time meteo_ecmwf = extract_meteo_ecmwf(inputdir, RELEASE_TIMES)

winds = process_wind.(meteo_ecmwf)

grid = CenteredGrid()
hist(azimuth_sample)

pdf = ParameterPdf(LogNormal, 10)

puff = GaussianPuff(
    grid,
    relstart,
    Minute.(RELSTEPS_MINUTE),
    [w[1] for w in winds],
    [w[2] for w in winds],
    RELEASE_RATE,
    RELHEIGHT
)

gaussian_montecarlo = GaussianMonteCarlo(puff, Dict(:azimuths => pdf), 3)
puff_mc = gaussian_montecarlo

@time puffs_da = gaussian_puffs(puff_mc, times);

jldsave(mc_concentrationfile(simname); puffs = puffs_da)