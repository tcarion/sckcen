using Flexpart
using DrWatson
using Rasters

include("fp_utils.jl")

function get_output(simname::String)
    fpsim = FlexpartSim(simpathnames(simname))
    outfiles = OutputFiles(fpsim)
    return outfiles
end

function Rasters.RasterStack(fpoutput::Flexpart.AbstractOutputFile)
    RasterStack(string(fpoutput))
end

function Rasters.Raster(fpoutput::Flexpart.AbstractOutputFile)
    stack = RasterStack(fpoutput)
    view(stack[:spec001_mr]; pointspec=1, nageclass=1)
end