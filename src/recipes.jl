using CairoMakie.Makie

# Makie.convert_arguments(ds::DiscreteSurface, da::AbstractDimArray) = convert_arguments(ds, dims(da, :X) |> collect, dims(da, :Y) |> collect, Matrix(da))
# Makie.convert_arguments(ds::Makie.SurfaceLike, da::AbstractDimArray) = convert_arguments(ds, dims(da, :X) |> collect, dims(da, :Y) |> collect, Matrix(da))
