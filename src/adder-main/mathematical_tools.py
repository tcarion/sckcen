# -*- coding: utf-8 -*-
"""
Created on Fri Mar 18 10:53:37 2022

@author: jfrankem
"""

import numpy as np

class data_collection(object):
    pass

def instance_of_data_collection():
    instance = data_collection()
    return instance

def create_square_centered_grid(bx,by,bz,Nx,Ny,Nz):
    """
    Parameters
    ----------
    bx : FLOAT
        Grid boundary in x direction (-xb to xb)
    by : FLOAT
        Grid boundary in y direction (-yb to yb).
    bz : FLOAT
        Grid boundary in z direction (0 to zb).
    Nx : INT
        Number of cells in x direction.
    Ny : INT
        Number of cells in y direction.
    Nz : INT
        Number of cells in z direction.

    Returns
    -------
    grid : DATA_COLLECTION
        Contains X, Y and Z meshgrids and various grid parameters.
    """
    grid = instance_of_data_collection()
    if Nx > 1:
        grid.dx = 2*bx/(Nx-1)
        x = np.linspace(-bx,bx,Nx)
    else:
        grid.dx = 1
        x = bx
    if Ny > 1:
        grid.dy = 2*by/(Ny-1)
        y = np.linspace(-by,by,Ny)
    else:
        grid.dy = 1
        y = by
    if Nz > 1:
        grid.dz = bz/(Nz-1)
        z = np.linspace(0,bz,Nz)
    else:
        grid.dz = 1
        z = bz
    grid.Nx = Nx
    grid.Ny = Ny
    grid.Nz = Nz
    grid.X,grid.Y,grid.Z = np.meshgrid(x,y,z)
    return grid

def wind_statistics(wd):
    """
    Parameters
    ----------
    wd : vector of wind directions
    
    Returns
    -------
    wd_avg : average of wd, accounting for cyclical nature of input
    wd_std : standard deviation of wd, accounting for cyclical nature of input
    """
    wd180  = wd[wd<=180]
    wd360  = wd[wd>180]
    
    N1      = len(wd180)
    N2      = len(wd360)
    A1      = np.sum(wd180)
    A2      = np.sum(wd360)
    S1      = np.sum(wd180**2)
    S2      = np.sum(wd360**2)
    
    if N2 == 0:
        wd_avg = A1/N1
        wd_std = np.sqrt((S1-(A1**2/N1))/(N1-1))
    elif N1 == 0:
        wd_avg = A2/N2
        wd_std = np.sqrt((S2-(A2**2/N2))/(N2-1))
    elif A2/N2 - A1/N1 < 180:
        wd_avg = (A1+A2)/(N1+N2)
        wd_std = np.sqrt((S1+S2-wd_avg**2*(N1+N2))/(N1+N2-1))
    elif A2/N2 - A1/N1 > 180:
        wd_avg = (A1+A2-N2*360)/(N1+N2)
        wd_std = np.sqrt((S1+S2-wd_avg**2*(N1+N2)+N2*360*(360-2*A2/N2))/(N1+N2-1))
        if wd_avg < 0:
            wd_avg = wd_avg + 360
    
    return wd_avg,wd_std

def WGS84_to_L72(Lat,Lng):
    """
    Parameters
    ----------
    Lat, Lng : Latitude / longitude in decimal degrees and in WGS84 datum 
    
    Returns
    -------
    x, y : Latitude / longitude in decimal degrees and in Belgian datum
    
    Reference
    ---------
    This algorithm is based on the algorithm supplied here:
    http://zoologie.umons.ac.be/tc/algorithms.aspx
    """
    
    # STEP ONE: CONVERT FROM WGS84 to Belgian Datum

    
    Haut = 0
    Lat = (np.pi/180)*Lat
    Lng = (np.pi/180)*Lng
     
    SinLat = np.sin(Lat)
    SinLng = np.sin(Lng)
    CoSinLat = np.cos(Lat)
    CoSinLng = np.cos(Lng)
    
    dx = 125.8
    dy = -79.9
    dz = 100.5
    da = 251.0
    df = 0.000014192702
     
    LWf = 1 / 297
    LWa = 6378388
    LWb = (1 - LWf) * LWa
    LWe2 = (2 * LWf) - (LWf * LWf)
    Adb = 1 / (1 - LWf)
     
    Rn = LWa / np.sqrt(1 - LWe2 * SinLat * SinLat)
    Rm = LWa * (1 - LWe2) / (1 - LWe2 * Lat * Lat) ** 1.5
     
    DLat = -dx * SinLat * CoSinLng - dy * SinLat * SinLng + dz * CoSinLat
    DLat = DLat + da * (Rn * LWe2 * SinLat * CoSinLat) / LWa
    DLat = DLat + df * (Rm * Adb + Rn / Adb) * SinLat * CoSinLat
    DLat = DLat / (Rm + Haut)
     
    DLng = (-dx * SinLng + dy * CoSinLng) / ((Rn + Haut) * CoSinLat)
    Dh = dx * CoSinLat * CoSinLng + dy * CoSinLat * SinLng + dz * SinLat
    Dh = Dh - da * LWa / Rn + df * Rn * Lat * Lat / Adb
     
    LatBel = ((Lat + DLat) * 180) / np.pi
    LngBel = ((Lng + DLng) * 180) / np.pi
    

    # STEP TWO: CONVERT FROM BELGIAN COORDINATES TO LAMBERT 72
    # Conversion from spherical coordinates to Lambert 72
    # Input parameters : Lat, Lng (spherical coordinates)
    # Spherical coordinates are in decimal degrees converted to Belgium datum!

    
    Lat = LatBel
    Lng = LngBel
    
    LongRef = 0.076042943        # =4°21'24"983
    bLamb = 6378388 * (1 - (1 / 297))
    aCarre = 6378388 ** 2
    eCarre = (aCarre - bLamb ** 2) / aCarre
    KLamb = 11565915.812935
    nLamb = 0.7716421928
    
    eLamb = np.sqrt(eCarre)
    eSur2 = eLamb / 2
    
    # conversion to radians
    Lat = (np.pi / 180) * Lat
    Lng = (np.pi / 180) * Lng
    
    eSinLatitude = eLamb * np.sin(Lat)
    TanZDemi = (np.tan((np.pi / 4) - (Lat / 2))) * \
       (((1 + (eSinLatitude)) / (1 - (eSinLatitude))) ** (eSur2))
    RLamb = KLamb * ((TanZDemi) ** nLamb)
    Teta = nLamb * (Lng - LongRef)
    
    x = 150000 + 0.01256 + RLamb * np.sin(Teta - 0.000142043)
    y = 5400000 + 88.4378 - RLamb * np.cos(Teta - 0.000142043)
    
    return x,y

def find_nearest(vec,val):
    """
    Parameters
    ----------
    vec : vector of values 
    val : value with respect to which neighbours are calculated

    Returns
    -------
    idx : indices of direct neighbours of val in vec

    """
    idxl = (np.abs(vec-val)).argmin()
    vec_sav = vec[idxl]
    vec[idxl] = np.inf
    idxu = (np.abs(vec-val)).argmin()
    idx = np.array([idxl,idxu])
    vec[idxl] = vec_sav
    
    return idx

def yx_to_wd(x,y):
    wd = np.mod(-(np.arctan2(y,x)*180/np.pi-90-180),360)
    r = np.sqrt(x**2+y**2)
    return wd, r

def rotate_grid(X,Y,wd):
    """
    Parameters
    ----------
    X : Meshgrid of longitudinal coordinates (Lambert 72) w.r.t. stack [m]
    Y : Meshgrid of longitudinal coordinates (Lambert 72) w.r.t. stack [m]
    wd: Wind direction (antiparallel to wind vector) [deg. w.r.t. North]

    Returns
    -------
    Xrot,Yrot : X and Y components of a meshgrid rotated by (wd-90)/180*np.pi

    """
    r = np.sqrt(X**2+Y**2)
    phi = np.arctan2(Y,X) - np.pi + (wd-90)/180*np.pi
    Xrot = r*np.cos(phi)
    Yrot = r*np.sin(phi)
    
    return Xrot,Yrot