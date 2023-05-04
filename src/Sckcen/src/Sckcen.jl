module Sckcen

import Unitful: Bq, g, kg, m, mol, s

using DataFrames
using Dates
using DelimitedFiles
using Downloads
using Geodesy
using Interpolations
# using Intervals
using Rasters
import Rasters: dims as ddims
using Unitful
using ValSplit

export AbstractElement, Element, Activity, get_mass, molar_mass, half_life, density
export gamma_dose_rate_factors, read_lara_file, time_resolved_dosimetry
export SourceTerm, build_source_term
export distance
export ReleasePoint, BBox, make_box
export FlexExtractRetrieval, FER
export round_area

const R = Rasters

include("constants.jl")
include("domain.jl")
include("geodesy.jl")
include("radioactivity.jl")
include("source.jl")

end # module
