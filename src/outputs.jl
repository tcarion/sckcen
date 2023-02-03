using Flexpart
using DrWatson
using Rasters

include("fp_utils.jl")

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

function time_integrate(conc)

end