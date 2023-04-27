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

function plot_smart_doses(df)
    alltimes = unique(df.time)
    itimes = 1:length(alltimes)
    yunit = unit(df.H10[1])

    by_sensor = groupby(df, :receptorName)
    Nplots = length(by_sensor)

    simcolors = [:green, :blue] 

    f = Figure(;resolution = (1200, 400))
    ga = f[1, 1] = GridLayout()
    axs = [Axis(ga[1, i]) for i in 1:Nplots]

    for (i, sensor_key) in enumerate(keys(by_sensor))
        cur_ax = axs[i]
        one_sensor = by_sensor[sensor_key]
        sensor_name = sensor_key[1]

        by_sim = groupby(one_sensor, :simname)
        for (j, sim_key) in enumerate(keys(by_sim))
            one_sim = by_sim[sim_key]
            if j == 1
                plot_sensor!(cur_ax, one_sim; label = "TELERAD")
            end
            linestyle = one_sim.simtype[1] == "flexpart" ? :dash : :dashdot
            scatterlines!(cur_ax, 1:length(one_sim.time), ustrip.(one_sim.H10); 
                label = one_sim.simname[1],
                linestyle,
                color = simcolors[j]
            )
        end
        # xrange = col == 1 ? (0:0.1:6pi) : (0:0.1:10pi)
        if i == 1
            cur_ax.ylabel = "H10 [$yunit]"
        else
            # cur_ax.yticks = nothing
            hideydecorations!(cur_ax, grid = false)
        end
        cur_ax.xticks = (itimes, Dates.format.(Time.(alltimes), "HH:MM"))
        cur_ax.title = sensor_name
        cur_ax.xticklabelrotation = deg2rad(15)
        ylims!(cur_ax, -2, 6)
        xlims!(cur_ax, 0.8, 6.2)
        # axislegend(cur_ax)
    end
    colgap!(ga, 0)
    first_axis_plots = plots(f.content[1])
    Legend(f[1, 1], first_axis_plots, [p.label[][1:clamp(20, 1:length(p.label[]))] for p in first_axis_plots]; 
        tellwidth = false,
        valign = :top,
        halign = :center
    )
    f
end