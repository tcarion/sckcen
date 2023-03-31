using GRIBDatasets
using DimensionalData
using GaussianDispersion

const GD = GaussianDispersion

gaussiandir(simname::String) = datadir("sims", simname)
concentrationfile(simname::String) = datadir("sims", simname, "concentration.jld2")
doseratefile(simname::String) = datadir("sims", simname, "dose_rates.jld2")

rotmat(θ) = [
    cosd(θ) -sind(θ) 0;
    sind(θ) cosd(θ) 0;
    0 0 1;
]

Base.@kwdef struct CenteredGrid
    # ! The domain in X and Y needs to be the same length. Otherwise, the plume is squeezed when it rotates (reach a squeezing maximum at +- 90°)
    # ? The reason should be investigated.
    # Yb = 250
    # Ny = 51
    Nx::Int = 101 
    Ny::Int = 101
    Nz::Int = 21
    Lx::Real = 500
    Ly::Real = 500
    Lz::Real = 200
end

get_lengths(grid::CenteredGrid) = (grid.Lx, grid.Ly, grid.Lz)
Base.size(grid::CenteredGrid) = (grid.Nx, grid.Ny, grid.Nz)
Base.length(grid::CenteredGrid) = grid.Nx * grid.Ny * grid.Nz

function get_ranges(grid::CenteredGrid)
    Nx, Ny, Nz = size(grid)
    Xb, Yb, Zb = get_lengths(grid)

    Xs = range(-Xb, Xb, length = Nx)
    Ys = range(-Yb, Yb, length = Ny)
    Zs = range(0, Zb, length = Nz)

    return (Xs, Ys, Zs)
end

Base.collect(grid::CenteredGrid) = collect(Iterators.product(get_ranges(grid)...))
Base.iterate(grid::CenteredGrid, args...) = iterate(Iterators.product(get_ranges(grid)...), args...)

function gaussian_puffs(grid::CenteredGrid, times, speeds, azimuths, Qs, h)
    grid_array = collect(grid)

    timely_conc = map(zip(speeds, azimuths, Qs)) do (wind_speed, wind_azimuth, Q)
        pg_class = pasquill_gifford(GD.Strong(), wind_speed) |> collect |> first
        θ = 360. .+ 90. .- wind_azimuth

        # ! I don't know why this minus sign is needed to get the correct result... If not, the plume rotate clockwise instead of counter-clockwise with theta.
        rotation = rotmat(-θ)
        gridrot = map(grid_array) do point
            rotation * collect(point)
        end

        meteo = MeteoParams(wind = wind_speed, stability = pg_class)

        release = GD.ReleaseParams(h = h, Q = Q)

        plume = GaussianPlume(release = release, meteo = meteo)

        # @btime conc = [plume(x, y, z) for x in Xs, y in Ys, z in Zs]
        # 94.425 ms (3427544 allocations: 70.28 MiB)

        [plume(point...) for point in gridrot]
    end

    TIC = reduce((x,y) -> x .+ y * 10 * 60, timely_conc; init = zero(timely_conc[1]))

    ## Conversion to Dimensional Arrays
    Xs, Ys, Zs = get_ranges(grid)
    spatial_dims = (X(Xs), Y(Ys), Z(Zs))

    conc_da = DimArray(
        cat(timely_conc..., dims = 4),
        (spatial_dims..., Ti(times))
    )

    TIC_da = DimArray(
        TIC,
        spatial_dims
    )

    conc_da, TIC_da
end