# -*- coding: utf-8 -*-
"""
Created on Tue Jul 12 09:22:23 2022

@author: jfrankem
"""

import pandas as pd
import numpy as np
import os

class data_collection(object):
    pass

def instance_of_data_collection():
    instance = data_collection()
    return instance

def read_lara(nuclide):
    """
    
    Description
    -----------
    This function processes information sheets from lara on the Web into usable
    numpy arrays. Download the nuclide of interest from Lara on the Web and put
    it into the data/nuclides folder. Right now, it only picks out the gammas.
    
    NB. Turn daughter nuclides off.

    Parameters
    ----------
    nuclide : name of nuclide in the form 'Se-75'
    
    Returns
    -------
    nuclide_data : collection of gamma energies [KeV] and intensities [0-1]
    
    References
    ----------
    http://www.nucleide.org/Laraweb/index.php
    
    """
    
    nuclide_data = instance_of_data_collection()
    
    absolute_path      = os.path.dirname(__file__)
    relative_directory = 'data/nuclides'
    directory = os.path.join(absolute_path,relative_directory)
    filenames = os.listdir(directory)
    filepaths = [os.path.join(directory, f) for f in filenames]
    for i in range(len(filenames)):
        if nuclide in filenames[i]:
            if not(nuclide[len(nuclide)-1] != 'm' and filenames[i][len(nuclide)] == 'm'):
                filepath = filepaths[i]            
    try:
        file = open(filepath)
    except:
        print('This nuclide is not yet included in data/nuclides. Go to '
              'http://www.nucleide.org/Laraweb/index.php and download '
              'the data and emissions file in ASCII text format, e.g.'
              'Se-75.lara.txt. Put it in the folder and rerun.')
    
    linenum = -1
    for line in file:
        linenum += 1
        if 'Nuclide' in line:
            nuclide_data.nuclide = line[line.find(' ; ')+3:-1].strip()
        elif 'Element' in line:
            nuclide_data.element = line[line.find(' ; ')+3:-1].strip()
        elif '----------' in line:
            linenum_start = linenum
    file.close()
        
    data = pd.read_csv(os.path.join(absolute_path,filepath),header=linenum_start+1,engine='python',sep=' ; ',index_col=False,usecols=range(5))
    data.drop(data.tail(1).index,inplace=True)
    data = data[data['Type']=='g']
    
    nuclide_data.Ey=np.squeeze(pd.DataFrame(data,columns = ['Energy (keV)']).to_numpy(dtype=np.float64))
    nuclide_data.I=np.squeeze(pd.DataFrame(data,columns = ['Intensity (%)']).to_numpy())/100 # to fractions
    
    return nuclide_data

def read_selenium_meteo(t0,t1):
    meteo       = instance_of_data_collection()
    abspath     = os.path.dirname(__file__)
    relpath     = 'data\meteo\met20190515.txt'
    data        = pd.read_csv(os.path.join(abspath,relpath),sep=';')
    meteo.t     = pd.to_datetime(data['Date_Time'],format='%Y-%m-%d %H:%M:%S').to_numpy()
    meteo_window = (meteo.t>=t0) == (meteo.t<=t1)
    meteo.t     = pd.to_datetime(data['Date_Time'],format='%Y-%m-%d %H:%M:%S').to_numpy()[meteo_window]
    meteo.T8    = np.squeeze(pd.DataFrame(data,columns = ['T8']).to_numpy())[meteo_window]
    meteo.T114  = np.squeeze(pd.DataFrame(data,columns = ['T114']).to_numpy())[meteo_window]
    meteo.Href  = 69
    meteo.Ta    = meteo.T8 + (meteo.T114-meteo.T8)/(114-8)*(60-8)
    meteo.U     = np.squeeze(pd.DataFrame(data,columns = ['Speed']).to_numpy())[meteo_window]
    meteo.wd    = np.squeeze(pd.DataFrame(data,columns = ['Azimuth']).to_numpy())[meteo_window]
    meteo.sig_wd= np.squeeze(pd.DataFrame(data,columns = ['AzimSigma']).to_numpy())[meteo_window]
    meteo.E     = np.squeeze(pd.DataFrame(data,columns = ['E_dT']).to_numpy())[meteo_window]
    meteo.T     = 10
    return meteo