using Distributed
# using ClusterManagers
# see https://github.com/JuliaParallel/ClusterManagers.jl
# https://discourse.julialang.org/t/running-julia-in-a-slurm-cluster/67614

# see also https://researchcomputing.princeton.edu/support/knowledge-base/julia

num_cores = parse(Int, ENV["SLURM_NPROCS"])
addprocs(num_cores; exeflags="--project")
# n_workers = parse(Int , ENV["SLURM_NTASKS"])
# addprocs_slurm(n_workers , topology =:master_worker)

println("Number of processes: ", nprocs())
println("Number of workers: ", nworkers())

using DrWatson
@quickactivate

@everywhere using Flexpart

FORCE_CLEAR_OUTPUTS = true
# simname = "FirstPuff_ELDA_res=0.0001_timestep=10_we=1000.0"
simname = ARGS[1]
fpsim = FlexpartSim{Ensemble}(datadir("sims", simname, "pathnames"))
println("Starting ensemble sim for $simname")

println("Removing previous outputs and log files")
if FORCE_CLEAR_OUTPUTS 
    rm.(readdir(fpsim[:output], join = true), recursive = true)
    rm.(filter(x -> occursin("member", x), readdir(Flexpart.getpath(fpsim), join = true)))
end

ens_tmp_dir = joinpath(Flexpart.getpath(fpsim), "tmp")
mkpath(ens_tmp_dir)

println("Remove previous temporary directory for pathnames")
rm.(readdir(ens_tmp_dir, join = true); recursive = true)

println("Creating temporary directory")
realizations_setup = Flexpart.setup_pathnames(fpsim; parentdir = ens_tmp_dir)

pmap(realizations_setup) do (imember, rfpsim)
    id, pid, host = myid(), getpid(), gethostname()
    println(id, " " , pid, " ", host)
    println("Starting sim for member $imember")
    log_path = joinpath(Flexpart.getpath(fpsim), "member$(imember).log")
    # Flexpart.run(rfpsim) 
    open(log_path, "w") do logf
        Flexpart.run(rfpsim) do io
            Flexpart.log_output(io, logf)
        end
    end
end

for i in workers()
    rmprocs(i)
end