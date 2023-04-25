using DrWatson
using CairoMakie
using AlgebraOfGraphics

include(srcdir("plots.jl"))
include(srcdir("process_doserates.jl"))

simname = "OPER_PG"

dose_rates_df = dose_rates_to_df(simname)

## Plot all dose rates for the simulations

