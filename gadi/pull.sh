#!/bin/bash
## Pull (refresh) the container image. copyq has internet access.
##   qsub gadi/pull.sh
#PBS -q copyq
#PBS -P jk72
#PBS -l walltime=01:25:00,ncpus=1,mem=38GB,jobfs=36GB,storage=gdata/jk72

export SINGULARITY_CACHEDIR=$PBS_JOBFS
export TMPDIR=$PBS_JOBFS
export SINGULARITY_DISABLE_CACHE=true
module load singularity

singularity pull --dir /g/data/jk72/mds581/sif_lib --force docker://ghcr.io/hypertidy/gdal-r-python-extras
