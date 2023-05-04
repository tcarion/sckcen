using Distributed

@everywhere begin
    using Pkg; Pkg.activate("/home/tcarion/projects/sckcen/")
    Pkg.instantiate(); Pkg.precompile()
end

@everywhere begin
    # load dependencies
    using Flexpart
    using Dates
    using DrWatson
    
    function convert_time(elapsed)
        ms = Millisecond(floor(elapsed * 1000))
        canonicalize(ms)
    end
end

simname = ARGS[1]
simpathname = datadir("sims", simname, "pathnames")
fpdirs = [FlexpartSim(simpathname)]
# release_dirs = filter(isdir, readdir(DIRPATH, join = true))
# fpdirs = joinpath.(release_dirs, "fpdir")
indexes = eachindex(fpdirs)

totaltime = @elapsed pmap(indexes) do i
    # @spawnat :any begin
    println("INSIDE LOOP: read $(fpdirs[i])")
    fpdir = fpdirs[i]
    println(fpdir)
    flush(stdout)
    simtime = @elapsed begin 
        open(joinpath(fpdir[:output], "output.log"), "w") do logf
            Flexpart.run(fpdir) do io
                line = readline(io, keep = true)
                write(logf, line)
                flush(logf)
            end
        end
    end
    
    println("FINISHED: $(fpdirs[i]) in: $(convert_time(simtime))")
    flush(stdout)
    open(joinpath(fpdir[:output], "time.log"), "w") do timef
        write(timef, simtime)
    end
    # end
end

println("#################################")
println("### TOTAL TIME: $(convert_time(totaltime))####")
println("#################################")

