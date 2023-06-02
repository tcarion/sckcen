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

# @everywhere begin
#     using Sckcen
#     using Unitful
#     using Rasters
#     using Rasters: dims as ddims
#     using JLD2
#     using Flexpart

#     include(srcdir("read_datasheet.jl"))
#     include(srcdir("process_doserates.jl"))
#     include(srcdir("outputs.jl"))
# end

# @everywhere using Sckcen
# @everywhere using Unitful
# @everywhere using Rasters
# @everywhere using Rasters: dims as ddims
# @everywhere using JLD2
# @everywhere using Flexpart

# @everywhere include(srcdir("read_datasheet.jl"))
# @everywhere include(srcdir("process_doserates.jl"))
# @everywhere include(srcdir("outputs.jl"))

@info "Loading Sckcen"
using Sckcen
@info "Loading Unitful"
using Unitful
@info "Loading Rasters"
using Rasters
using Rasters: dims as ddims
@info "Loading JLD2"
using JLD2
@info "Loading Flexpart"
using Flexpart
include(srcdir("read_datasheet.jl"))
include(srcdir("process_doserates.jl"))
include(srcdir("outputs.jl"))

element_id = :Se75
simname = "ENFO_BE_20190513T00_res=0.0001_timestep=10_we=1000.0"
println("Starting conversion to dose rates of ensembles for $simname")

DOSE_RATE_SAVENAME = dose_rate_savename(simname)

rho = 0.001161u"g/cm^3"
nuclide_data = read_lara_file("Se-75")

sensor_numbers = [0, 1, 2, 3, 4, 7, 8, 12, 14, 15]

println("Preparing output")
output = get_outputs(simname)
conc_mass = isempty(output) ? combine_ensemble_outputs(simname) : Raster(getpath(first(output)))
conc = prepare_output_for_doserate(conc_mass)

times = ddims(conc, Ti) |> collect

sensors_dose_rates = read_dose_rate_sensors()

dose_for_each_member = pmap(ddims(conc, :member)) do imember
    id, pid, host = myid(), getpid(), gethostname()
    println(id, " " , pid, " ", host)
    @info "Computing member $imember on id=$id and host=$host"
    @time compute_dose_rates(conc[member = At(imember)], sensor_numbers, sensors_dose_rates, nuclide_data)
end

dose_rates_da = cat(dose_for_each_member...; dims = ddims(conc, :member))

dose_rates_da = DimStack(dose_rates_da...; 
    metadata = Dict(
        "simtype" => "flexpart",
        "ensemble" => is_ensemble,
        "simname" => simname,
        "membertype" => is_ensemble ? "ensemble_forecast" : ""
    )
)
## Save dose rates
save(dose_rate_file(simname), Dict(DOSE_RATES_SAVENAME => dose_rates_da))
@info "Dose rates saved at $(dose_rate_file(simname))"

for i in workers()
    rmprocs(i)
end