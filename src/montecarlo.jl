using Distributions

include("gaussian.jl")

mc_gaussiandir(simname::String) = datadir("sims", "montecarlo", simname)
mc_concentrationfile(simname::String) = joinpath(mc_gaussiandir(simname), "concentration.jld2")

const MC_GAUSSIAN_SAVENAME = "puffs"

abstract type AbstractPdf end

azimuth_pdf(μ, σ) = LogNormal(μ, σ)

"""
    logn_sample(μ, σ; N = 1000)
Produce `N` samples from a Log-Normal distribution with mean `μ` and standard deviation `σ`
"""
logn_sample(μ, σ; N = 1000) = log.(rand(LogNormal(μ, σ), N))

struct ParameterPdf <: AbstractPdf
    distrib::Type{<:Distribution}
    std::Float64
end

(pdf::ParameterPdf)(μ) = pdf.distrib(μ, pdf.std)

struct GaussianMonteCarlo
    puff::GaussianPuff
    distributions::Dict{Symbol, <:AbstractPdf}
    N::Int64
end

function run_puff(puff_mc::GaussianMonteCarlo)
    puff = puff_mc.puff
    N = puff_mc.N
    grid_array = collect(puff.grid)
    @unpack speeds, azimuths, rates, h = puff
    results = map(1:N) do i
        distrib = puff_mc.distributions[:azimuths]
        pdf_azimuths = distrib.(azimuths)
        perturbed_azimuths = log.(rand.(pdf_azimuths))

        timely_conc = map(zip(speeds, perturbed_azimuths, rates)) do (wind_speed, wind_azimuth, Q)

            pg_class = pasquill_gifford(GD.Strong(), wind_speed) |> collect |> first
            θ = 360. .+ 90. .- wind_azimuth
    
            gridrot = rotate_grid(grid_array, θ)
    
            meteo = MeteoParams(wind = wind_speed, stability = pg_class)
    
            release = GD.ReleaseParams(h = h, Q = Q)
    
            plume = GaussianPlume(release = release, meteo = meteo)
    
            # @btime conc = [plume(x, y, z) for x in Xs, y in Ys, z in Zs]
            # 94.425 ms (3427544 allocations: 70.28 MiB)
    
            [plume(point...) for point in gridrot]
        end
        perturbed_azimuths, timely_conc
    end

    return results
end

function gaussian_puffs(puff_mc::GaussianMonteCarlo, times)
    results = run_puff(puff_mc)

    das = map(results) do result
        perturbed_azimuths = result[1]
        timely_conc = result[2]

        da = to_dimarray(timely_conc, puff_mc.puff.grid, times)

        da_perturb = DimArray(perturbed_azimuths, (Ti(times),); name = :pert_azim)

        DimStack(da..., da_perturb)
    end
end