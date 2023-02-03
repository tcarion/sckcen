using DrWatson
@quickactivate

include(srcdir("outputs.jl"))

element_id = :Se75
run_name = "FirstPuff_OPER_res=0.0005_timestep=30"

stack = RasterStack(get_output(run_name)[1])
conc = Raster(get_output(run_name)[1])

plot(stack[])
plot(log.(conc[height = 1, Ti = 1]))