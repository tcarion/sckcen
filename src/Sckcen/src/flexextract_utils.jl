
abstract type DatasetStream  end

struct ELDA <: DatasetStream end
struct ENDA <: DatasetStream end
struct ENFO <: DatasetStream end
struct OPER <: DatasetStream end

Base.string(ds::DatasetStream)::String = split(string(typeof(ds)), ".")[end]

Base.@kwdef mutable struct FlexExtractRetrieval{DS<:DatasetStream}
    startdate::DateTime = DateTime(2019,5,15,0)
    stopdate::DateTime = DateTime(2019,5,16,0)
    bbox::BBox = BBox(53., 0., 49., 7.)
    gridres::Float64 = 1.
    stream::DS
end

const FER = FlexExtractRetrieval

get_area(fer::FER) = collect(fer.bbox)

# FlexExtractRetrieval(bbox::BBox; kw...) = FlexExtractRetrieval(; area = collect(bbox), kw...)

control_template_file(fer::FlexExtractRetrieval{ELDA}) = "CONTROL_OD.ELDA.FC.eta.ens.double"
control_template_file(fer::FlexExtractRetrieval{ENFO}) = "CONTROL_OD.ENFO.PF.ens"
control_template_file(fer::FlexExtractRetrieval{OPER}) = "CONTROL_OD.OPER.FC.eta.highres"

