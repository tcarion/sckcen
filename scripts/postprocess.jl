using DrWatson
@quickactivate

include(srcdir("outputs.jl"))

element_id = :Se75
simname = "FirstPuff_OPER_res=0.0005_timestep=10"

tobq_filename = convert_units_and_save(simname)


tobq = load_conc_in_bq(simname)
