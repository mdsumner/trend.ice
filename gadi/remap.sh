#!/bin/bash
## Remap a kerchunk Parquet BRAN store to /g/data paths and check it.
##   qsub -v SRC=/g/data/.../bran.parq,DST=/g/data/.../bran-gdata.parq gadi/remap.sh
## (run from the trend.ice checkout: PBS starts in $PBS_O_WORKDIR)
#PBS -q normal
#PBS -P jk72
#PBS -l walltime=01:00:00,ncpus=1,mem=16GB,storage=gdata/jk72+gdata/gb6
#PBS -l wd

source gadi/env.sh
$RUN python3 tools/kerchunk_remap.py "$SRC" --scan
$RUN python3 tools/kerchunk_remap.py "$SRC" "$DST" --check
