#! /bin/bash
simpath=$1
cd $simpath
. /home/tcarion/spack/share/spack/setup-env.sh
spack load flexpart
echo "Starting flexpart at $(pwd)"
FLEXPART