using DrWatson
@quickactivate
using AlgebraOfGraphics, CairoMakie
import AlgebraOfGraphics: dims as aogdims
import AlgebraOfGraphics: data as aogdata
using JLD2
using Unitful
using DataFramesMeta
using Dates

const AOG = AlgebraOfGraphics

include(srcdir("process_doserates.jl"))

simname = "FirstPuff_OPER_PF_20230329_res=0.0005"
simname = "OPER_PG"
sensor_name = "IMR/M02"

DOSE_RATE_SAVENAME = dose_rate_savename(simname)

only_equal(df, colname, value) = select(subset(df, colname => x -> x .== value), Not(colname))

df = to_df_and_save(simname)
units = string(unit(df[1, 3]))
df_sensor = only_equal(df, :receptorName, sensor_name)
by_member = groupby(df_sensor, :member)

map_h10 = :H10 => (x -> ustrip.(x)) => "H10 [$units]"
h10_to_times = mapping(:times, map_h10, color = :member => nonnumeric)

title = "Dose rates for ensembles. Date: $(Date(df.times[1]))"
##
f = Figure()
plt = aogdata(df_sensor) * 
    h10_to_times * 
    visual(Lines)
draw!(f, plt)
f
##
