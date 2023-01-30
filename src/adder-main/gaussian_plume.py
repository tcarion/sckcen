# -*- coding: utf-8 -*-
"""
Created on Mon Mar 14 14:46:05 2022

@author: jfrankem
"""

import numpy as np
import math
from mathematical_tools import rotate_grid

def stability_class(Tup,Tdown,Hup,Hdown,u69):
    """
    
    Description
    -----------
    This functions calculates the Bultynck-Malet stability class based on the
    formulation in their 1972 paper, but with the absolute temperature rather 
    than the potential temperature.
    
    Parameters
    ----------
    Tup     : Temperature at Hup (top of mast) [deg. Celsius]
    Tdown   : Temperature at Hdown (bottom of mast) [deg. Celsius]
    Hup     : Height of top temperature measurement [m]
    Hdown   : Height of bottom temperature measurement [m]
    u69     : Wind speed at a height of 69 m [m/s]

    Returns
    -------
    E       : Bultynck-Malet stability class [1-7]

    References
    ----------
    Bultynck, H, & Malet, L.M. (1972) ‘Evaluation of atmospheric dilution
        factors for effluents diffused from an elevated continuous point 
        source’, Tellus, 24(5), pp.455–377 [online]. 
        DOI: https://doi.org/10.1111/j.2153-3490.1972.tb01572.x
        
    """
    
    S = (Tup-Tdown)/(Hup-Hdown)/u69**2
    lamb = np.log10(np.abs(S)*1e6)
    if u69 > 11.5:
        E = 7
    elif S > 0:
        if lamb >= 2.75:
            E = 1
        elif lamb > 1.75:
            E = 2
        else:
            E = 3
    elif S<0:
        if lamb <= 2:
            E = 3
        elif lamb < 2.75:
            E = 4
        elif lamb <3.3:
            E = 5
        else:
            E = 6
    return E
            

def dispersion_BM(E,X,T):
    """
    
    Description
    -----------
    This function calculates the horizontal and vertical dispersion
    coefficients (Bultynck and Malet, 1972) and corrects them for the averaging
    time of the meteo data (Beychock, 1994).
    
    Parameters
    ----------
    E : Bultynck-Malet stability class [1-7]
    X : Meshgrid of wind-aligned coordinate [m]
    T : Meteo averaging time [minute]

    Returns
    -------
    sigy : Horizontal dispersion coefficient [m]
    sigz : Vertical dispersion coefficient [m]
    
    References
    ----------
    Bultynck, H, & Malet, L.M. (1972) ‘Evaluation of atmospheric dilution
        factors for effluents diffused from an elevated continuous point 
        source’, Tellus, 24(5), pp.455–377 [online]. 
        DOI: https://doi.org/10.1111/j.2153-3490.1972.tb01572.x
    Beychock, M.R. (1994) Fundamentals of stack gas dispersion, 3rd ed.,
        Irvine: M.R. Beychock.
        
    """
    A = np.array([   0.235,  0.297,  0.418,  0.586,  0.826,  0.946,  1.043])
    a = np.array([   0.796,  0.796,  0.796,  0.796,  0.796,  0.796,  0.698])
    B = np.array([   0.311,  0.382,  0.520,  0.700,  0.950,  1.321,  0.819])
    b = np.array([   0.711,  0.711,  0.711,  0.711,  0.711,  0.711,  0.669])
    T_BM = 60
    corr = (220.2 + T)/(220.2 + T_BM)
    sigy = corr*A[E-1]*X**a[E-1]
    sigz = corr*B[E-1]*X**b[E-1]
    return sigy, sigz

def single_plume(X,Y,Z,U,E,Q,H,T,switch_plume_type,L=1e20):
    """
    
    Description
    ----------
    This function calculates a 3D concentration profile in a plume-aligned
    geometry (x pointed along the wind direction).
    
    Parameters
    ----------
    X : Meshgrid of longitudinal coordinates (Lambert 72) w.r.t. stack [m]
    Y : Meshgrid of longitudinal coordinates (Lambert 72) w.r.t. stack [m]
    Z : Meshgrid of heights w.r.t. ground height [m]
    U : Wind speed [m/s]
    E : Bultynck-Malet stability class [1-7]
    Q : Source term [Bq/s]
    H : Effective release height [m]
    T : Meteo averaging time [minutes]
    switch_plume_type : 'none' for totally absorbing ground, 'ground' for 
    reflection in ground plane. 'inversion' includes both ground-plane and 
    capping inversion reflection.

    Returns
    -------
    c : Meshgrid with x-aligned Gaussian plume profile [Bq/m^3]
    
    References
    ----------
    Stockie, J.M. (2011) ‘The Mathematics of Atmospheric Dispersion Modelling’,
        SIAM Review, 53(2) [online]. DOI: https://doi.org/10.1137/10080991X.
    Beychock, M.R. (1994) Fundamentals of stack gas dispersion, 3rd ed.,
        Irvine: M.R. Beychock.

    """

    sigy,sigz   = dispersion_BM(E,X,T)
    prefac      = Q/(2*np.pi*U*sigy*sigz)
    f           = np.exp(-Y**2/(2*sigy**2))
    g1          = np.exp(-(Z-H)**2/(2*sigz**2))
    g2          = np.exp(-(Z+H)**2/(2*sigz**2))
    g3          = 0
    L           = inversion_layer(E,L)
    
    for im in range(10):
        g3  = g3                                   + \
            np.exp(-(Z-H-2*(im+1)*L)**2/(2*sigz**2)) + \
            np.exp(-(Z+H+2*(im+1)*L)**2/(2*sigz**2)) + \
            np.exp(-(Z+H-2*(im+1)*L)**2/(2*sigz**2)) + \
            np.exp(-(Z-H+2*(im+1)*L)**2/(2*sigz**2)) 
    if "none" in switch_plume_type:
        c   = prefac*f*(g1)
    elif "ground" in switch_plume_type:
        c   = prefac*f*(g1+g2)
    elif "inversion" in switch_plume_type:
        c   = prefac*f*(g1+g2+g3)
    
    c = np.nan_to_num(c)
    return c

def multi_plume(grid,meteo,source,Umin,switch_plume_type,switch_plume_rise,L=1e20):
    """
    
    Description
    -----------
    Main function that loops over simple_plume while also setting correct
    velocities and accounting for plume rise.
    
    Parameters
    ----------
    grid : class of type data_collection [1] which contains
    all information about the numerical grid
    meteo : class of type data_collection [1] that contains
    all meteorological parameters
    source : class of type data_collection [1] that contains
    all source data
    Umin : lower cut-off for the wind speed [m/s]
    switch_plume_type : 'none' for totally absorbing ground, 'ground' for 
    reflection in ground plane. 'inversion' includes both ground-plane and 
    capping inversion reflection.
    switch_plume_rise : 'none' for no plume rise, 'hmax' for 
    constant plume rise, 'hx' for plume rise as a function of
    grid.X. Required by plume_rise().

    Returns
    -------
    c : 4D array, where the first three axes are filled with
    concentration fields and the fourth is the time axis [Bq/m3]
    TIC: time-integrated concentration field [Bq*s/m3]
    
    """
    
    c = np.zeros([grid.X.shape[0],grid.X.shape[1],grid.X.shape[2],meteo.wd.shape[0]])
    TIC = np.zeros([grid.X.shape[0],grid.X.shape[1],grid.X.shape[2]])
    
    if L == 1e20:
        L=L*np.ones(len(meteo.wd))
    else:
        try:
            if len(L) == len(meteo.wd):
                pass
        except:
            L = L*np.ones(len(meteo.wd))       
                
    for i in range(len(meteo.wd)):
        if np.mod(i,50) == 0:
            print("Completion : ", end="")
            print(math.floor(i/len(meteo.wd)*100),flush=True)
        Xrot,Yrot = rotate_grid(grid.X, grid.Y, meteo.wd[i])
        Us = velocity_profile(meteo.Href, source.Hs, meteo.U[i], meteo.E[i], Umin)
        dH,dhmax = plume_rise(Xrot,source.Vs,source.Ts,meteo.Ta[i],Us,switch_plume_rise)
        Heff = source.Hs + dH
        Hmax = source.Hs + dhmax
        Ueff = velocity_profile(meteo.Href,Hmax, meteo.U[i], meteo.E[i], Umin)
        ci = single_plume(Xrot,Yrot,grid.Z,Ueff,meteo.E[i],source.Q[i],Heff,meteo.T,switch_plume_type,L[i])
        c[:,:,:,i] = ci
        TIC = TIC + ci*meteo.T*60
    return c, TIC

def plume_rise(X,Vs,Ts,Ta,U,switch_plume_rise):
    """
    
    Description
    -----------
    This function calculates plume rise as function of distance for all down-
    wind distances based on Briggs' equations for hot buoyant bent-over plumes
    (Briggs,1971;Beychock,1994)
    
    Parameters
    ----------
    X : Meshgrid containing the wind-aligned coordinates.
    Vs : Gas flow out of the stack ('debiet') [m**3/s]
    Ts : Gas temperature out of the stack [deg.C]
    Ta : Ambient temperature at stack height [deg.C]
    U : Wind speed at stack height [m]
    switch_plume_rise : 'none' for no plume rise, 'hmax' for 
    constant plume rise, 'hx' for plume rise as a function of X.

    Returns
    -------
    dH : Array for all X pf plume rise relative to stack height [m]
    dhmax : Upper limit of dH [m]
    
    References
    ----------
    Briggs, G.A. (1971) ‘ME 8E – Some recent analyses of plume rise 
        observations: des analyses recentes des observations de panache 
        montante’ in Englund, H.M. & Beery, W.T. (eds.)  Proceedings of the
        Second International Clean Air Congress. New York: Academic Press, 
        pp.1029–1032 [online].
        DOI: https://doi.org/10.1016/B978-0-12-239450-8.50183-0
    Beychock, M.R. (1994) Fundamentals of stack gas dispersion, 3rd ed.,
        Irvine: M.R. Beychock.
    
    """
    if Ta > Ts: 
        dH = 0
        dhmax = 0
        return dH,dhmax
    
    g = 9.81 #m/s^2
    F = g*Vs/np.pi*(Ts-Ta)/(Ts+273.15)
    
    if F <= 55:
        xmax = 49*F**0.625
    else:
        xmax = 119*F**0.4
    
    dhmax = 1.6*F**(1/3)*xmax**(2/3)/U
    if "none" in switch_plume_rise:
        dH = 0
    elif "hmax" in switch_plume_rise:
        dH = dhmax + 0*X
    elif "hx" in switch_plume_rise:
        gt = X>xmax
        dH = 0.*X
        dH[gt]=dhmax
        dH[~gt] = 1.6*F**(1/3)*X[~gt]**(2/3)/U
    dH = np.nan_to_num(dH)
    return dH, dhmax

def inversion_layer(E,L):
    L_BM = np.array([ 400, 400, 800, 850, 900, 1300, 800])
    if L > L_BM[E] or L < 0:
        L = L_BM[E]
    return L

def velocity_profile(Href,Hnew,Uref,E,Umin):
    """
    
    Description
    -----------
    This function scales a wind speed at reference height to a wind speed at a
    new height (Kretzschmar, Mertens and Vanderborght, 1984) using stability-
    dependent parameters m:
        
        E        1       2       3       4       5       6       7
        m     0.53    0.40    0.33    0.23    0.16    0.10    0.33

    Parameters
    ----------
    Href : Height at which Uref is obtained [m]
    Hnew : Height to which Uref should be scaled [m]
    Uref : Wind speed at Href [m/s]
    E    : Bultynck-Malet stability class [1-7]
    Umin : Lower limit for Unew [m/s]
        
    Returns
    -------
    Unew : Wind speed at Hnew [m/s]

    Reference
    ---------
    Kretzschmar, J.G., Mertens, I. & Vanderborght, B. (1984) Sensitivity, 
        applicability and validation of bi-gaussian off- and on-line models for
        the evaluation of the consequences of accidental releases in nuclear 
        facilities: final report contract no. SR-028-B. Luxemburg: Commission
        of the European Communities:
            
    """
    
    m = np.array([0.53, 0.40, 0.33, 0.23, 0.16, 0.10, 0.33])
    Unew = Uref*(Hnew/Href)**m[E-1]
    Unew = np.maximum(Unew,Umin)
    return Unew

def deposition(TIC0,vdep):
    """
    
    Description
    -----------
    Very simple deposition model.

    Parameters
    ----------
    TIC0 : time-integrated concentration field at ground level (z=0) [Bq*s/m3]
    vdep : deposition velocity [m/s]

    Returns
    -------
    DEP : Deposited amount of material [Bq/m2]

    """
    
    DEP = vdep*TIC0
    return DEP