using DrWatson
using DataFrames
using DataFramesMeta
using Makie
using Statistics
# using AlgebraOfGraphics

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

function plot_sensor!(ax, data; color = :orange, label = data.receptorName[1], witherror=true)
    xs = 1:length(data.time)
    ys = ustrip.(data.H10)
    scatterlines!(ax, xs, ys; label, color, markersize = 3)
    witherror && errorbars!(ax, xs, ys, ustrip.(data.value_std); color = (color, 0.7), whiskerwidth = 9, label)
end
plot_h10!(ax, data; color = :blue, label = "Simulation") = scatterlines!(ax, 1:length(data.time), ustrip.(data.H10); label, color)

function plot_smart_doses(df; Ncols = 3)
    alltimes = unique(df.time)
    itimes = 1:length(alltimes)
    yunit = unit(df.H10[1])

    by_sensor = groupby(df, :receptorName)
    Nplots = length(by_sensor)

    simcolors = Makie.wong_colors()
    simcolors = [:red, :blue, :green, :yellow, :purple]

    ax_indices = fldmod1.(1:Nplots, Ncols)
    f = Figure(;
        # resolution = (1200, 400)
    )
    ga = f[1, 1] = GridLayout()
    axs = [Axis(ga[row, col]) for (row, col) in ax_indices]
    labels = String[]

    for (i, sensor_key) in enumerate(keys(by_sensor))
        row, col = ax_indices[i]
        cur_ax = axs[i]
        one_sensor = by_sensor[sensor_key]
        sensor_name = sensor_key[1]

        measures = subset(one_sensor, :simtype => x -> x .== "measure")
        sims = subset(one_sensor, :simtype => x -> (!).(x .== "measure"))

        if !isempty(measures)
            filter_dates = @rsubset measures :time in unique(sims.time)
            filter_dates = sort(filter_dates, :time)
            plot_sensor!(cur_ax, filter_dates; label = "TELERAD", color = :blue)
            # @info "pushing when i = $i, key $sensor_key"
            push!(labels, "TELERAD")
        end

        by_sim = groupby(sims, :simname)
        for (j, sim_key) in enumerate(keys(by_sim))
            one_sim = by_sim[sim_key]
            linestyle = one_sim.simtype[1] == "flexpart" ? :dash : :dashdot
            if one_sim.isensemble[1] == false
                scatterlines!(cur_ax, 1:length(one_sim.time), ustrip.(one_sim.H10); 
                    label = one_sim.simname[1],
                    linestyle,
                    color = simcolors[j]
                )
                # @info "pushing when j = $j, key $sim_key"

                push!(labels, one_sim.simname[1])
            else
                by_time = groupby(one_sim, :time)
                ensemble_mean = combine(by_time, :H10 => mean,:H10 => std)
                ys = ustrip.(ensemble_mean.H10_mean)
                scatterlines!(cur_ax, 1:length(ensemble_mean.time), ys;
                    color = simcolors[j],
                    linestyle,
                )
                errorbars!(cur_ax, 1:length(ensemble_mean.time), ys, ustrip.(ensemble_mean.H10_std); 
                    color = (simcolors[j], 0.7), 
                    whiskerwidth = 9, 
                )
            end
        end
        # xrange = col == 1 ? (0:0.1:6pi) : (0:0.1:10pi)
        if col == 1
            cur_ax.ylabel = "H10 [$yunit]"
        else
            # cur_ax.yticks = nothing
            hideydecorations!(cur_ax, grid = false)
        end
        cur_ax.xticks = (itimes, Dates.format.(Time.(alltimes), "HH:MM"))
        cur_ax.title = sensor_name
        cur_ax.xticklabelrotation = deg2rad(15)
        Makie.ylims!(cur_ax, -2, 6)
        Makie.xlims!(cur_ax, 0.8, 6.2)
        # axislegend(cur_ax)
    end
    colgap!(ga, 0)
    first_axis_plots = plots(f.content[1])
    combined_plots = [first_axis_plots[1:2], first_axis_plots[3:end]...]
    # Legend(f[1, 1], combined_plots, _get_label.(combined_plots); 
    # # Legend(f[1, 1], combined_plots, labels; 
    #     tellwidth = false,
    #     valign = :top,
    #     halign = :center
    # )
    f
end

function plot_each_spread!(ax, by_recept; base_date = DateTime("2019-05-15T14:00:00"))
    nrecept = length(unique(by_recept.receptorName))
    nrecept !== 1 && error("Only 1 receptor allowed, got $nrecept")
    by_fc = groupby(by_recept, :forecast_start)
    colors = [:blue, :red, :green, :purple, :yellow]
    for (i, fc_key) in enumerate(keys(by_fc))
        fc = by_fc[fc_key]
        fc_start = fc_key.forecast_start
        diffh = Hour(base_date - DateTime(fc_start)).value
        plot_spread!(ax, fc; label = "T-$(diffh)h", color = colors[i])
    end
end

function plot_obs!(ax, obs)
    scatterlines!(ax, 1:nrow(obs), ustrip.(obs.value); label="obs", markersize = 3, color = :black)
end

function plot_spread!(ax, data; color = :blue, label = "", linestyle = :solid, with_fun = mean)
    H10 = combine(groupby(data, :time), :H10 => with_fun => :mean_or_median)
    H10_std = combine(groupby(data, :time), :H10 => std)
    alltimes = unique(data.time)
    itimes = 1:length(alltimes)
    means = ustrip.(H10.mean_or_median)
    spreads = ustrip.(H10_std.H10_std)
    scatterlines!(ax, itimes, means; color, label, linestyle)
    band!(ax, itimes, means .- spreads, means .+ spreads; color = (color, 0.2))
end

function plot_spreads_all_receptors(ens, oper, obs; receptors = ["IMR/M03", "IMR/M04", "IMR/M15"], resolution = (1200, 650))
    Nplots = length(receptors)
    # ax_indices = fldmod1.(1:Nplots, Ncols)
    yunit = unit(ens.H10[1])
    
    f = Figure(; resolution)
    ga = f[1,1] = GridLayout()
    alltimes = unique(ens.time)
    itimes = 1:length(alltimes) 
    # axs = [Axis(ga[row, col]) for (row, col) in ax_indices]
    axs_each = [Axis(ga[1, i]) for i in 1:length(receptors)]
    axs_all = [Axis(ga[2, i]) for i in 1:length(receptors)]

    for (i, receptor) in enumerate(receptors)
        ax_each = axs_each[i]
        ax_each.title = receptor
        ax_each.xticks = (itimes, Dates.format.(Time.(alltimes), "HH:MM"))

        ylims!(ax_each, -2, 6)
        plot_obs!(ax_each, @rsubset obs :longName == receptor)
        plot_each_spread!(ax_each, @rsubset ens :receptorName==receptor)


        ax_all = axs_all[i]
        ax_all.xticks = (itimes, Dates.format.(Time.(alltimes), "HH:MM"))
        ax_all.xticklabelrotation = deg2rad(10)
        ylims!(ax_all, -2, 6)

        plot_obs!(ax_all, @rsubset obs :longName == receptor)
        plot_spread!(ax_all, @rsubset ens :receptorName == receptor; color = :blue, label = "all ens")
        scatterlines!(ax_all, itimes, ustrip.((@rsubset oper :receptorName == receptor).H10); color = :red, label = "deterministic")

        if i == 1
            axislegend(ax_each)
            axislegend(ax_all)
            ax_each.ylabel = "H10 [$yunit]"
            ax_all.ylabel = "H10 [$yunit]"
        else
            hideydecorations!(ax_each, grid=false)
            hideydecorations!(ax_all, grid=false)
        end
        hidexdecorations!(ax_each, grid=false)
    end
    colgap!(ga, 0)
    rowgap!(ga, 10)
    f
end

function _get_label(p)
    lab = p isa Vector ? p[1].label[] : p.label[]
    return lab[1:clamp(20,1:length(lab))]
end