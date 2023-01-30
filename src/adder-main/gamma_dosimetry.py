# -*- coding: utf-8 -*-
"""
Created on Tue Mar 15 16:16:26 2022

@author: Jens Peter
"""
import numpy as np
import pandas as pd
import os
from scipy.interpolate import interp1d

from mathematical_tools import find_nearest


def attenuation(Ey,rho):
    """
    
    Description
    -----------
    Yields attenuation coefficients of air as described in Martin (2013).
    mu is given in 1/cm while mu/rho and mu_en/rho are given in in cm2/g. We
    thus first multiply by rho to obtain mu(rho) and mu_en(rho), and we also
    multiply by a factor 100 to convert from 1/cm to 1/m.

    Parameters
    ----------
    Ey : Energy of gamma ray [keV]
    rho : Density of air [g/cm3]

    Returns
    -------
    mu : Mass attennuation [1/m]
    mu_en : Mass energy absorption [1/m]
    
    References
    ----------
    Martin, J.E. (2013) Physics for Radiation Protection, Weinheim: Wiley. DOI:
        https://doi.org/10.1002/9783527667062

    """
    data = np.array([
    #keV    mu          mu/rho      mu_en/rho
   [10,     0.0062,     5.120,      4.742,],
   [15,     0.0019,     1.614,      1.334,],
   [20,     0.0009,     0.7779,     0.5389,],
   [30,     4.26E-4,    0.3538,     0.1537,],
   [40,     2.99E-4,    0.2485,     0.0683,],
   [50,     2.51E-4,    0.2080,     0.0410,],
   [60,     2.26E-4,    0.1875,     0.0304,],
   [70,     2.10E-4,    0.1744,     0.0255,],
   [80,     2.00E-4,    0.1662,     0.0241,],
   [100,    1.86E-4,    0.1541,     0.0233,],
   [150,    1.63E-4,    0.1356,     0.0250,],
   [200,    1.49E-4,    0.1233,     0.0267,],
   [300,    1.29E-4,    0.1067,     0.0287,],
   [400,    1.15E-4,    0.0955,     0.0295,],
   [500,    1.05E-4,    0.0871,     0.0297,],
   [600,    9.71E-5,    0.0806,     0.0295,],
   [662,    9.34E-5,    0.0775,     0.0293,],
   [800,    8.52E-5,    0.0707,     0.0288,],
   [1000,   7.66E-5,    0.0636,     0.0279,],
   [1173,   7.05E-5,    0.0585,     0.0271,],
   [1250,   6.86E-5,    0.0569,     0.0267,],
   [1333,   6.62E-5,    0.0550,     0.0263,],
   [1500,   6.24E-5,    0.0518,     0.0255,],
   [2000,   5.36E-5,    0.0445,     0.0235,],
   [3000,   4.32E-5,    0.0358,     0.0206,],
   [4000,   3.71E-5,    0.0308,     0.0187,],
   [5000,   3.31E-5,    0.0275,     0.0174,],
   [6000,   3.04E-5,    0.0252,     0.0165,],
   [6129,   3.01E-5,    0.0250,     0.0164,],
   [7000,   2.83e-5,    0.0235,     0.0159,],
   [7115,   2.82E-5,    0.0234,     0.0158,],
   [10000,  2.46E-5,    0.0205,     0.0145]]);

    mu_itp = interp1d(data[:,0], data[:,2])
    mu_en_itp = interp1d(data[:,0], data[:,3])
    mu = mu_itp(Ey)*rho*100
    mu_en = mu_en_itp(Ey)*rho*100
    
    return mu, mu_en

def buildup_factor(Ey,mux,database):
    
    """
    
    Description
    -----------
    
    Parameters
    ----------
    Ey : Energy of gamma ray [keV]
    mux : No. of mean free paths (mass attenuation * distance) [-]
    database: "martin" for build-up factors from Martin (2013) or "nucl" for
    data from Trubey et al (1991). [-]
    
    Returns
    -------
    B : Array of build-up factors (for each mux) [-]
    
    References
    ----------
    Martin, J.E. (2013) Physics for Radiation Protection, Weinheim: Wiley. DOI:
        https://doi.org/10.1002/9783527667062
    Trubey, D. K., C. M. Eisenhauer, A. Foderaro, D. V. Gopinath, Y. Harima, 
        J. H. Hubbell, K. Shure and S. Su., 1991: Gamma-ray attenuation 
        coefficients and buildup factors for engineering materials, American 
        National Standard ANSI/ANS-6.4.3-1991, American Nuclear Society, 
        La Grange Park.
    """
    
    
    if "martin" in database:
        Ba = np.array([
       # 0.1MeV  0.5MeV  1MeV    2MeV    3MeV    4MeV    5MeV    6MeV    8MeV    10MeV
        [1.00,   1.00,   1.00,   1.00,   1.00,   1.00,   1.00,   1.00,   1.00,   1.00],    #mux=0.0
        [2.35,   1.6,    1.47,   1.38,   1.34,   1.31,   1.29,   1.27,   1.23,   1.2],     #mux=0.5
        [4.46,   2.44,   2.08,   1.83,   1.71,   1.63,   1.57,   1.52,   1.43,   1.37],    #mux=1.0
        [11.4,   4.84,   3.6,    2.81,   2.46,   2.25,   2.09,   1.97,   1.8,    1.68],    #mux=2.0
        [22.5,   8.21,   5.46,   3.86,   3.22,   2.85,   2.6,    2.41,   2.15,   1.97],    #mux=3.0
        [38.4,   12.6,   7.6,    4.96,   4,      3.46,   3.11,   2.85,   2.5,    2.26],    #mux=4.0
        [59.9,   17.9,   10.0,   6.13,   4.79,   4.07,   3.61,   3.28,   2.84,   2.54],    #mux=5.0
        [87.8,   24.2,   12.7,   7.35,   5.6,    4.69,   4.12,   3.71,   3.17,   2.82],    #mux=6.0
        [123,    31.6,   15.6,   8.61,   6.43,   5.31,   4.62,   4.14,   3.51,   3.1],     #mux=7.0
        [166,    40.1,   18.8,   9.92,   7.26,   5.94,   5.12,   4.57,   3.84,   3.37],    #mux=8.0
        [282,    60.6,   25.8,   12.6,   8.97,   7.19,   6.13,   5.42,   4.49,   3.92],    #mux=10.0
        [800,    134,    47.0,   20,     13.4,   10.3,   8.63,   7.51,   6.08,   5.25],    #mux=15.0
        [1810,   241,    72.8,   27.9,   17.9,   13.5,   11.1,   9.58,   7.64,   6.55],    #mux=20.0
        [3570,   385,    103,    36.2,   22.5,   16.7,   13.6,   11.6,   9.17,   7.84],    #mux=25.0
        [6430,   567,    136,    45,     27.2,   19.9,   16.1,   13.6,   10.7,   9.11]])    #mux=30.0
        Eya = np.array([0.1,0.5,1,2,3,4,5,6,8,10])*1000
        muxa = np.array([0.0,0.5,1,2,3,4,5,6,7,8,10,15,20,25,30])
    
    elif "nucl" in database:
        Ba = np.array([
   # MeV 0.015  0.02    0.03    0.04    0.05    0.06    0.08    0.1     0.15    0.2     0.3     0.4     0.5     0.6     0.8     1       1.5     2       3       4       5       6       8       10      15
        [1,     1,      1,      1,      1,      1,      1,      1,      1,      1,      1,      1,      1,      1,      1,      1,      1,      1,      1,      1,      1,      1,      1,      1,      1],     # mux=0      
        [1.12,  1.27,   1.76,   2.2,    2.48,   2.58,   2.52,   2.35,   2.16,   1.9,    1.75,   1.66,   1.6,    1.56,   1.5,    1.47,   1.42,   1.38,   1.34,   1.31,   1.29,   1.27,   1.23,   1.2,    1.15],  # mux=0.5
        [1.17,  1.41,   2.31,   3.38,   4.28,   4.76,   4.83,   4.46,   3.83,   3.28,   2.83,   2.59,   2.44,   2.33,   2.17,   2.08,   1.92,   1.83,   1.71,   1.63,   1.57,   1.52,   1.43,   1.37,   1.28],  # mux=1
        [1.25,  1.62,   3.19,   5.85,   8.72,   10.8,   12,     11.4,   9.21,   7.74,   6.2,    5.37,   4.84,   4.46,   3.94,   3.6,    3.09,   2.81,   2.46,   2.25,   2.09,   1.97,   1.8,    1.68,   1.49],  # mux=2
        [1.31,  1.79,   3.99,   8.47,   14.1,   18.9,   22.9,   22.5,   18.2,   15,     11.4,   9.45,   8.21,   7.34,   6.19,   5.46,   4.42,   3.86,   3.22,   2.85,   2.6,    2.41,   2.15,   1.97,   1.7],   # mux=3
        [1.36,  1.93,   4.75,   11.2,   20.5,   29.1,   37.9,   38.4,   31.5,   25.6,   18.7,   14.9,   12.6,   10.9,   8.88,   7.6,    5.86,   4.96,   4,      3.46,   3.11,   2.85,   2.5,    2.26,   1.9],   # mux=4
        [1.39,  2.04,   5.46,   14.1,   27.6,   41.5,   57.4,   59.9,   49.9,   40,     28.2,   21.8,   17.9,   15.3,   12,     10,     7.42,   6.13,   4.79,   4.07,   3.61,   3.28,   2.84,   2.54,   2.11],  # mux=5
        [1.43,  2.15,   6.14,   17,     35.7,   56.1,   82,     87.8,   74.2,   58.9,   40.2,   30.2,   24.2,   20.3,   15.5,   12.7,   9.08,   7.35,   5.6,    4.69,   4.12,   3.71,   3.17,   2.82,   2.3],   # mux=6
        [1.46,  2.25,   6.79,   20.1,   44.6,   73.2,   112,    123,    105,    82.8,   54.9,   40.2,   31.6,   26,     19.4,   15.6,   10.8,   8.61,   6.43,   5.31,   4.62,   4.14,   3.51,   3.1,    2.5],   # mux=7
        [1.48,  2.34,   7.43,   23.3,   54.4,   92.7,   148,    166,    144,    112,    72.7,   52,     40.1,   32.5,   23.7,   18.8,   12.7,   9.92,   7.26,   5.94,   5.12,   4.57,   3.84,   3.37,   2.7],   # mux=8
        [1.53,  2.5,    8.69,   30,     76.8,   140,    242,    282,    249,    192,    118,    81.1,   60.6,   47.9,   33.5,   25.8,   16.7,   12.6,   8.97,   7.19,   6.13,   5.42,   4.49,   3.92,   3.08],  # mux=10
        [1.62,  2.83,   11.8,   49,     151,    316,    636,    800,    735,    545,    304,    191,    134,    100,    64.9,   47,     27.7,   20,     13.4,   10.3,   8.63,   7.51,   6.08,   5.25,   4.03],  # mux=15
        [1.68,  3.11,   14.8,   71.4,   256,    596,    1350,   1810,   1700,   1220,   624,    365,    241,    173,    105,    72.8,   40.2,   27.9,   17.9,   13.5,   11.1,   9.58,   7.64,   6.55,   4.96],  # mux=20
        [1.74,  3.35,   18,     97.2,   395,    1010,   2540,   3570,   3410,   2360,   1120,   611,    385,    266,    154,    103,    53.9,   36.2,   22.5,   16.7,   13.6,   11.6,   9.17,   7.84,   5.87],  # mux=25
        [1.78,  3.56,   21.5,   126,    574,    1600,   4390,   6430,   6210,   4150,   1820,   938,    567,    379,    210,    136,    68.5,   45,     27.2,   19.9,   16.1,   13.6,   10.7,   9.11,   6.75],  # mux=30
        [1.82,  3.74,   25.4,   159,    798,    2410,   7140,   10600,  10500,  6770,   2770,   1350,   788,    512,    274,    173,    84,     54,     32,     23.1,   18.5,   15.4,   12.3,   10.4,   7.58],  # mux=35
        [1.85,  3.88,   29.7,   195,    1070,   3480,   11100,  15700,  17000,  10500,  4010,   1870,   1050,   665,    345,    212,    100,    63.2,   36.7,   26.3,   21,     16.9,   14.1,   11.6,   8.31]]) # mux=40
        Eya = np.array([0.015,0.02,0.03,0.04,0.05,0.06,0.08,0.1,0.15,0.2,0.3,0.4,0.5,0.6,0.8,1,1.5,2,3,4,5,6,8,10,15])*1000
        muxa = np.array([0,0.5,1,2,3,4,5,6,7,8,10,15,20,25,30,35,40])
   
    iEy = find_nearest(Eya,Ey)
    B = 0*mux
    for i in range(mux.shape[0]):
        for j in range(mux.shape[1]):
            for k in range(mux.shape[2]):
                imux= find_nearest(muxa, mux[i,j,k])
                B0 = Ba[imux[0],iEy[0]] + (Ba[imux[0],iEy[1]]-Ba[imux[0],iEy[0]]) / (Eya[iEy[1]]-Eya[iEy[0]]) * (Ey-Eya[iEy[0]])
                B1 = Ba[imux[1],iEy[0]] + (Ba[imux[1],iEy[1]]-Ba[imux[1],iEy[0]]) / (Eya[iEy[1]]-Eya[iEy[0]]) * (Ey-Eya[iEy[0]])
                B[i,j,k]  = B0+(B1-B0)/(muxa[imux[1]]-muxa[imux[0]])*(mux[i,j,k]-muxa[imux[0]])
    
    return B

def Gy_to_H10(Ka,Ey):
    """
    
    Description
    -----------
    Convert air kerma to ambient dose equivalent for given gamma energy based
    on tabulated data (ICRP, 1996)

    Parameters
    ----------
    Ka : Dose (rate) in air kerma [Gy (Gy/s)]
    Ey : Energy of gamma ray [keV]

    Returns
    -------
    H10 : Ambient dose equivalent (rate) [Sv (Sv/s)]
    
    Reference
    ---------
    ICRP (1996) ‘Conversion Coefficients for use in Radiological Protection 
        against External Radiation. ICRP Publication 74’, Annals of the ICRP, 
        26(3–4). Available at:
        https://www.icrp.org/publication.asp?id=ICRP%20Publication%2074
        (Accessed: 2 February 958 2022)

    """
    data = np.array([
    [0.010,  0.008],
    [0.015,  0.26],
    [0.020,  0.61],
    [0.030,  1.10],
    [0.040,  1.47],
    [0.050,  1.67],
    [0.060,  1.74],
    [0.080,  1.72],
    [0.100,  1.65],
    [0.150,  1.49],
    [0.200,  1.40],
    [0.300,  1.31],
    [0.400,  1.26],
    [0.500,  1.23],
    [0.600,  1.21],
    [0.800,  1.19],
    [1,      1.17],
    [1.5,    1.15],
    [2,      1.14],
    [3,      1.13],
    [4,      1.12],
    [5,      1.11],
    [6,      1.11],
    [8,      1.11],
    [10,     1.10]])

    itp = interp1d(data[:,0],data[:,1])
    H10 = Ka*itp(Ey/1e3)
    
    return H10

def gamma_dose_rate(grid,xq,yq,zq,c,nuclide_data,rho,database):
    """
    
    Description
    -----------
    Calculates the gamma dose rate to air (Healy and Baker, 1968) and the 
    ambient dose equivalent rate.

    Parameters
    ----------
    grid : class of type data_collection [1] which contains
    all information about the numerical grid
    xq : x coordinate of the detector (relative to stack) [m]
    yq : y coordinate of the detector (relative to stack) [m]
    zq : z coordinate of the detector (relative to stack) [m]
    c : concentration at all grid points [Bq/m3]
    nuclide : name of radionuclide of form 'Se-75'
    rho : Density of air [g/cm3]
    database : "martin" for build-up factors from Martin (2013) or "nucl" for
    data from Trubey et al (1991). [-]

    Returns
    -------
    H10 : Ambient dose equivalent rate [nSv/h]
    D : Gamma dose rate to air (air kerma) [nGy/h]
    
    References
    ----------
    Healy, J.W. & Baker, R.E. (1968) ‘Radioactive cloud-dose calculations’ in 
        Slade, D.H. (ed.) Meteorology and atomic energy. Springfield: Technical 
        Information Center/U.S. Department of Energy, pp.301.
    
    """
    
    D = 0
    H10 = 0
    for i in range(len(nuclide_data.Ey)):
        mu, mu_en = attenuation(nuclide_data.Ey[i],rho)
        prefac = 1/100*0.0364*(1293/(rho*1e6))*mu_en*nuclide_data.Ey[i]*1e-3
        q = c*grid.dx*grid.dy*grid.dz/3.7e10
        mux = mu*np.sqrt((grid.X-xq)**2+(grid.Y-yq)**2+(grid.Z-zq)**2)
        B = buildup_factor(nuclide_data.Ey[i],mux,database)
        mux[mux==0] = np.inf
        Dr= prefac*q*B*np.exp(-mux)/(mux/mu)**2*1e9*3600 #nGy/h
        Dr[grid.Z==0] = Dr[grid.Z==0]/2
        Di = nuclide_data.I[i]*np.sum(Dr)
        D = D + Di
        H10 = H10 + Gy_to_H10(Di,nuclide_data.Ey[i])
    return H10, D

def gamma_factors(grid,xq,yq,zq,nuclide_data,rho,database):
    """
    
    Description
    -----------
    Calculates the gamma dose rate to air (Healy and Baker, 1968) and the 
    ambient dose equivalent rate for a unit release and outputs an array gf_H10
    for all grid cells such that:
        
        ambient dose equivalent rate = sum(gf_H10*c)
        
    where c is the array of concentrations. This implementation is much faster
    than gamma_dose_rate() when running over a longer timeseries.

    Parameters
    ----------
    grid : class of type data_collection [1] which contains
    all information about the numerical grid
    xq : x coordinate of the detector (relative to stack) [m]
    yq : y coordinate of the detector (relative to stack) [m]
    zq : z coordinate of the detector (relative to stack) [m]
    nuclide : name of radionuclide of form 'Se-75'
    rho : Density of air [g/cm3]
    database : "martin" for build-up factors from Martin (2013) or "nucl" for
    data from Trubey et al (1991). [-]

    Returns
    -------
    gf_H10 : Ambient dose equivalent rate contributions of all grid cells for a
    unit release [(nSv/h)/(Bq/m3)]
    gf_D : Gamma dose rate to air contributions of all grid cells for a
    unit release [(nGy/h)/(Bq/m3)]
    
    References
    ----------
    Healy, J.W. & Baker, R.E. (1968) ‘Radioactive cloud-dose calculations’ in 
        Slade, D.H. (ed.) Meteorology and atomic energy. Springfield: Technical 
        Information Center/U.S. Department of Energy, pp.301.
    
    """
    gf_D = np.zeros(grid.X.shape)
    gf_H10 = np.zeros(grid.X.shape)
    c = np.zeros(grid.X.shape) + 1
    for i in range(nuclide_data.Ey.shape[0]):
        mu, mu_en = attenuation(nuclide_data.Ey[i],rho)
        prefac = 1/100*0.0364*(1293/(rho*1e6))*mu_en*nuclide_data.Ey[i]*1e-3
        q = c*grid.dx*grid.dy*grid.dz/3.7e10
        mux = mu*np.sqrt((grid.X-xq)**2+(grid.Y-yq)**2+(grid.Z-zq)**2)
        B = buildup_factor(nuclide_data.Ey[i],mux,database)
        mux[mux==0] = np.inf
        Dr= prefac*q*B*np.exp(-mux)/(mux/mu)**2*1e9*3600 #nGy/h
        Dr[grid.Z==0] = Dr[grid.Z==0]/2
        Di = nuclide_data.I[i]*Dr
        gf_D = gf_D + Di
        gf_H10 = gf_H10 + Gy_to_H10(Di,nuclide_data.Ey[i])
    return gf_H10, gf_D

def time_resolved_H10(grid,xq,yq,zq,c,nuclide_data,rho,database):
    gf_H10,gf_D = gamma_factors(grid, xq, yq, zq, nuclide_data, rho, database)
    N = c.shape[3]
    H10, D = np.zeros(N), np.zeros(N)
    for i in range(N):
        H10[i]=np.sum(c[:,:,:,i]*gf_H10)
        D[i]=np.sum(c[:,:,:,i]*gf_D)
    return H10, D
