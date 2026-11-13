#!/bin/bash
## BRAN 5-day composites from the /g/data-remapped stores, then onto the ice grid.
##   qsub gadi/bran.sh            (from the trend.ice checkout; after remap_bran.sh)
#PBS -q normal
#PBS -P jk72
#PBS -l walltime=08:00:00,ncpus=4,mem=64GB,storage=gdata/jk72+gdata/gb6
#PBS -l wd

source gadi/env.sh
BASE=${BASE:-/g/data/jk72/mds581}
$RUN python3 scripts/bran_composites.py $BASE/bluelink-gdata $BASE/trend-ice/bran5day --years ${FIRST:-1997} ${LAST:-2025}
$RUN Rscript scripts/bran_to_icegrid.R $BASE/trend-ice/bran5day $BASE/trend-ice/bran_icegrid
