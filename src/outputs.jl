using Flexpart
using DrWatson
using Rasters
using Sckcen
using Unitful

include("fp_utils.jl")

const NCF_TO_BQ_PREFIX = "conc_bq.nc"

function get_outputs(simname::String)
    fpsim = FlexpartSim(simpathnames(simname))
    outfiles = OutputFiles(fpsim)
    return outfiles
end

function Rasters.RasterStack(fpoutput::Flexpart.AbstractOutputFile)
    RasterStack(string(fpoutput))
end

function Rasters.Raster(fpoutput::Flexpart.AbstractOutputFile)
    stack = RasterStack(fpoutput)
    view(sum(stack[:spec001_mr], dims = :pointspec); nageclass=1, pointspec = 1)
end

function Sckcen.mass2activity(raster::AbstractRaster)
    raster = deepcopy(raster)
    mdata = Rasters.metadata(raster)
    input_units = uparse(replace(mdata["units"], " " => "*", "-" => "^-"))
    M = mdata["weightmolar"] * u"g/mol"
    th = 1. / mdata["decay"] * log(2) * u"s"
    raster_units = raster .* input_units
    ustrip.(uconvert.(u"Bq/m^3", Sckcen.mass2activity.(raster_units, M, th)))
end

function convert_units_and_save(simname::AbstractString; force = false)
    output = get_outputs(simname)[1]
    conc_savename = joinpath(dirname(string(output)), NCF_TO_BQ_PREFIX)
    if isfile(conc_savename)
        !force && (return conc_savename)
    end
    conc = Raster(string(output))
    sumed = sum(conc, dims = :pointspec)[nageclass = 1, pointspec = 1]
    convert_to_qb(sumed)

    Rasters.write(conc_savename, to_bq)
end

function convert_to_bq(conc::AbstractRaster)
    to_bq = Sckcen.mass2activity(conc)
    Rasters.metadata(to_bq)["units"] = "Bq/m^3"
    return to_bq
end

function load_conc_in_bq(simname)
    filename = datadir("sims", simname, "output", NCF_TO_BQ_PREFIX)
    Raster(filename)
end

raster_to_units(raster) = raster * uparse(replace(Rasters.metadata(raster)["units"], " " => "*", "-" => "^-"))

function time_integrate(conc)

end