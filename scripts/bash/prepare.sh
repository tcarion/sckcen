#!/usr/bin/env bash
fepath="$HOME/flex_extract/flex_extract_v7.1.2"
# PYTHON_PATH="/home/tcarion/.julia/conda/3/bin/python"
PYTHON_PATH="$HOME/miniconda3/bin/python"
dirpath="$HOME/projects/sckcen/data/extractions/andy_example_ensemble_era5_2022"
control=`find $dirpath -name "*CONTROL*"`


$PYTHON_PATH $fepath/Source/Python/Mods/prepare_flexpart.py --controlfile $dirpath/CONTROL_ERA5_ENS --inputdir $dirpath/input --outputdir $dirpath/output --ppid 4931 > $dirpath/prepare.log