module Sckcen

using Interpolations
using Geodesy
using Dates
using Unitful
import Unitful: s, g, mol, Bq, m, kg
using Downloads
using DataFrames
using ValSplit
using Intervals

export AbstractElement, Element, Activity, get_mass, molar_mass, half_life, density
export SourceTerm, build_source_term
export ReleasePoint, BBox, make_box
export FlexExtractRetrieval, FER
export round_area

include("constants.jl")
include("domain.jl")
include("radioactivity.jl")
include("source.jl")

end # module
