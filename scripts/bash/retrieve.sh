#!/usr/bin/env bash
fe_version="7.1.2"
fepath="$HOME/flex_extract/flex_extract_v$fe_version"
PYTHON_PATH="$HOME/.julia/conda/3/bin/python"
# PYTHON_PATH="home/tcarion/miniconda3/bin/python"
dirpath="$HOME/projects/sckcen/data/extractions/$1"
control=`find $dirpath -name "*CONTROL*"`

$PYTHON_PATH ${fepath}/Source/Python/submit.py --controlfile $control --inputdir $dirpath/input --outputdir $dirpath/output > $dirpath/submit_$fe_version.log