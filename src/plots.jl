using DrWatson

using CairoMakie
using AlgebraOfGraphics

function plotmarker!(ax, x, y, text; color = :white, fontsize = 12, offset = (0,8))
    p = Point2f(x, y)

    Makie.scatter!(ax, p;
        markersize = 15,
        color = :green,
        overdraw = true,
        marker = :star4
    )
    Makie.text!(ax, p;
        text = text,
        color,
        fontsize,
        offset,
        align = (:center, :bottom),
        overdraw = true,
        glowwidth = 10.,
        glowcolor = :red,
        strokewidth = 20,
    )
end

plot_sensor!(ax, data; color = :orange, label = data.receptorName[1]) = scatterlines!(ax, 1:length(data.time), ustrip.(data.value); label, color)
plot_h10!(ax, data; color = :blue, label = "Simulation") = scatterlines!(ax, 1:length(data.time), ustrip.(data.H10); label, color)
