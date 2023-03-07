
ENV["PYCALL_JL_RUNTIME_PYTHON"] = Sys.which("python")
using PyCall

using DrWatson
@quickactivate

using Dates
using Rasters
using DataFrames
using Unitful
using JLD2
# using Pkg

# ENV["PYTHON"]= "/home/tcarion/miniconda3/bin/python"
# Pkg.build("PyCall")

pushfirst!(pyimport("sys")."path", srcdir("adder-main"))

script = py"""
# import sys
# sys.path.append('/home/tcarion/projects/sckcen/src/adder-main')
import numpy as np

from gaussian_plume import multi_plume
from gamma_dosimetry import time_resolved_H10
from mathematical_tools import create_square_centered_grid
from read_inputs import instance_of_data_collection, read_selenium_meteo ,read_lara

# We set up the numerical grid
Nx, Ny, Nz = 101, 101, 21
Xb, Yb, Zb = 500, 500, 200
grid = create_square_centered_grid(Xb, Yb, Zb, Nx, Ny, Nz)

# We set up the source term. If you are working with larger datasets,
# it might be advisable to instead set up an automatic data import function 
# like the example written for the meteorological data below. This function
# could go into read_inputs.py.
source = instance_of_data_collection()
source.Hs = 60 # height of the BR2 stack [m]
source.Ts = 15 # temperature of exhausted gas [deg. Celsius]
source.Vs = 150000/3600 # gas outflow rate [m3/s]
source.Q = np.array([9.1,8.6,4.1,1.6,1.,0.9])*1e6 # source term [Bq/s]
nuclide_data = read_lara('Se-75')

# We retrieve the meteorological data
t0              = np.datetime64('2019-05-15 15:20')
t1              = np.datetime64('2019-05-15 16:10')
meteo           = read_selenium_meteo(t0, t1)

# We set up the locations of the dose rate stations.
xq = np.array([-157.2,-262.2,-305.8])
yq = np.array([-142.8,-121.6,  44.9])
zq = np.array([   1.0,   1.0,   1.0])

# We set some options for the dispersion simulation
switch_plume_type = 'inversion' # include ground and inversion reflection
switch_plume_rise = 'hx' # plume rise varies as function of downwind distance
L = 1e20 # constrain the dispersion by the mixing height of the atmosphere
Umin = 0.5 # lower limit of the wind speed [m/s]

# We set some options for the gamma dose rate calculations
database = 'nucl' # We use the ANS (1991) build-up factors because they go to lower keV than Martin (2013)
rho = 0.001161 # air density [g/cm3]
dose_rate_type = 0 # set to 0 for ambient dose equivalent rate [nSv/h] or to 1 for air kerma [nGy/h]

# To compare with measurements, we add some real data below. Observations are
# from TELERAD (courtesy of FANC-ACFN). Backgrounds are subtracted.
H10T = np.transpose(np.array([   
    [ 3.8684,    3.7368,     0.4053],
    [ 2.0684,    2.2368,     1.8053],
    [ 1.5684,    2.5368,    -0.0947],
    [ 1.1684,    0.5368,     0.4053],
    [-0.2316,    0.3368,     0.4053],
    [ 0.9684,    0.7368,    -0.1947]]))
sig2H10T = np.array([ 1.0542,	0.9457,	    0.8013])


c, TIC = multi_plume(grid, meteo, source, Umin, switch_plume_type, switch_plume_rise)
"""

gpm_conc = py"c";

grid = py"grid"
xs = grid.X[1,:,1]
ys = grid.Y[:, 1, 1]
zs = grid.Z[1, 1, :]
meteo = py"meteo"
t = meteo.t
ts = map(t) do ti
    tistr = py"str($ti)"
    DateTime(split(tistr, ".")[1])
end
conc = DimArray(gpm_conc, (X = xs, Y = ys, Z = zs, Ti =ts))

Rasters.write(joinpath(datadir("adder"), "adder_example.nc"), conc)

py"""
# Calculate the dose rate in time for each detector
H10 = np.zeros([len(xq),len(source.Q)])
D = np.zeros([len(xq),len(source.Q)])
for i in range(len(xq)):
    h10, d = time_resolved_H10(grid,xq[i],yq[i],zq[i],c,nuclide_data,rho,database)
    H10[i,:]= h10
    D[i,:] = d
"""

sensor_names = ["IMR/M03", "IMR/M15", "IMR/M04"]
H10 = py"H10"
D = py"D"
H10T = py"H10T"

dfs = map(enumerate(sensor_names)) do (i, sensor_name)
    DataFrame(longName = fill(sensor_name, length(ts)) ,times = ts, H10 = H10[i, :] * u"nSv/hr", D = D[1, :] * u"nSv/hr", sensor = H10T[i, :] * u"nSv/hr")
end
adder_dose_rates = vcat(dfs...)

jldsave(joinpath(datadir("adder"), "adder_dose_rates.jld2"); adder_dose_rates)
