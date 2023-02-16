# -*- coding: utf-8 -*-

import numpy as np
import matplotlib.pyplot as plt
import matplotlib.dates as mdates 

from gaussian_plume import multi_plume
from gamma_dosimetry import time_resolved_H10
from mathematical_tools import create_square_centered_grid
from read_inputs import instance_of_data_collection, read_selenium_meteo ,read_lara

"""
1. Set-up of the computation
"""

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
source.Q = np.array([8.3,8.3,8.3,0.,0.,0.])*1e6 # source term [Bq/s]
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

"""
2. Actual computation
"""

# Calculate concentration fields in time via a Gaussian plume model
c, TIC = multi_plume(grid, meteo, source, Umin, switch_plume_type, switch_plume_rise)

# Calculate the dose rate in time for each detector
H10 = np.zeros([len(xq),len(source.Q)])
for i in range(len(xq)):
    H10[i,:]=time_resolved_H10(grid,xq[i],yq[i],zq[i],c,nuclide_data,rho,database)[0]

"""
3. Visualisation
"""

fig = plt.figure()
gs = fig.add_gridspec(1,3)
ax1,ax2,ax3 = gs.subplots(sharex=True, sharey=True)

ax1.errorbar(meteo.t,H10T[0,:], yerr=sig2H10T[0],capsize=5)
ax2.errorbar(meteo.t,H10T[1,:], yerr=sig2H10T[1],capsize=5)
ax3.errorbar(meteo.t,H10T[2,:], yerr=sig2H10T[2],capsize=5)
ax1.plot(meteo.t,H10[0,:])
ax2.plot(meteo.t,H10[1,:])
ax3.plot(meteo.t,H10[2,:])

date_format = mdates.DateFormatter('%H:%M')

ax1.set_ylim([-2, 6])
ax1.tick_params(labelrotation=45)
ax2.tick_params(labelrotation=45)
ax3.tick_params(labelrotation=45)
ax1.xaxis.set_major_formatter(date_format)
ax2.xaxis.set_major_formatter(date_format)
ax3.xaxis.set_major_formatter(date_format)
ax1.set_box_aspect(1)
ax2.set_box_aspect(1)
ax3.set_box_aspect(1)
ax1.tick_params(direction='in',right=True,top=True)
ax2.tick_params(direction='in',right=True,top=True)
ax3.tick_params(direction='in',right=True,top=True)
ax1.set_title('IMR/M03')
ax2.set_title('IMR/M15')
ax3.set_title('IMR/M04')
ax1.set_ylabel('nSv/h')
plt.legend(['GPM','TELERAD'])