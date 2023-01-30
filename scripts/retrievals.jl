##
using Sckcen
using Flexpart
using Flexpart.FlexExtract
using DrWatson
using Dates
include(srcdir("fe_utils.jl"))
##

##
retrieval_to_load = "OPER_left=1.52_lower=49.0_right=8.67_upper=53.5_gridres=0.2_startdate=2019-05-15T00:00:00_stopdate=2019-05-16T00:00:00"
loaded_fer = load_fer(retrieval_to_load)
##

##
relpoint = ReleasePoint()
bbox = make_box(relpoint, 500e3, 500e3)
##

fer_elda = FlexExtractRetrieval(; bbox, stream = Sckcen.ELDA())
fer_enfo = FlexExtractRetrieval(; bbox, stream = Sckcen.ENFO())
fer_oper = FlexExtractRetrieval(; bbox, stream = Sckcen.OPER(), gridres = 0.2)

FlexExtract.create(fer_enfo)
FlexExtract.create(fer_oper)
FlexExtract.save(fer_oper)
save_fer(fer_enfo)
save_fer(fer_oper)

fedir = FlexExtractDir(loaded_fer)
open(joinpath(fedir.path, "submit.log"), "w") do logfile
    println(logfile, "STARTING RETRIEVAL FROM JULIA (flex_extractv7.1.2) at $(Dates.now())")
    flush(logfile)
    FlexExtract.submit(fedir) do feout
        line = readline(feout, keep=true)
        write(logfile, line)
        flush(logfile)
    end
end

FlexExtract.preparecmd(FlexExtractDir(fer_oper))