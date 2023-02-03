using Flexpart.FlexExtract
using DrWatson
using Sckcen


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


DrWatson.default_prefix(fer::FER) = string(fer.stream)*"_"*savename(fer.bbox)

function FlexExtract.create(fer::FER; force = false)
    retrieval_dir = datadir("extractions", savename(fer))
    fedir = FlexExtract.create(retrieval_dir; force, control = Sckcen.control_template_file(fer))    
    return fedir
end

function FlexExtract.save(fer::FER)
    fedir = FlexExtractDir(fer)
    fecontrol = FeControl(fedir)
    @unpack startdate, stopdate, bbox, gridres = fer
    step_hour = 1
    FlexExtract.set_steps!(fecontrol, startdate, stopdate, step_hour)
    FlexExtract.set_area!(fecontrol, round_area(bbox))
    fecontrol[:GRID] = gridres
    FlexExtract.save(fecontrol)
    fecontrol
end

FlexExtract.FlexExtractDir(fer::FER) = FlexExtractDir(datadir("extractions", savename(fer)))

save_fer(fer::FER) = wsave(datadir("extractions", savename(fer), "data.jld2"), Dict("fer" => fer))
load_fer(fer::FER) = load(datadir("extractions", savename(fer), "data.jld2"))["fer"]
load_fer(name::String) = load(datadir("extractions", name, "data.jld2"))["fer"]

function submit(fer::FER)
    fedir = FlexExtractDir(fer)
    open(joinpath(fedir.path, "submit.log"), "w") do logfile
        FlexExtract.submit(fedir) do feout
            line = readline(feout, keep=true)
            write(logfile, line)
            flush(logfile)
        end
    end
end

function prepare(fer::FER)
    fedir = FlexExtractDir(fer)
    open(joinpath(fedir.path, "prepare.log"), "w") do logfile
        FlexExtract.prepare(fedir) do feout
            line = readline(feout, keep=true)
            write(logfile, line)
            flush(logfile)
        end
    end
end

function ls_input(fer::FER)
    fedir = FlexExtractDir(fer)
    readdir(fedir[:input])
end

function ls_output(fer::FER)
    fedir = FlexExtractDir(fer)
    readdir(fedir[:output])
end