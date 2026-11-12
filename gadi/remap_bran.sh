#!/bin/bash
## Remap the published Bluelink (BRAN2020 daily) kerchunk stores from
## source.coop straight to /g/data paths, then check them against /g/data/gb6.
## copyq: needs internet for source.coop.
##   qsub gadi/remap_bran.sh            (from the trend.ice checkout)
#PBS -q copyq
#PBS -P jk72
#PBS -l walltime=02:00:00,ncpus=1,mem=16GB,storage=gdata/jk72+gdata/gb6
#PBS -l wd

source gadi/env.sh
SRC=https://data.source.coop/ausantarctic/ausantarctic-scratch/bluelink
OUT=${OUT:-/g/data/jk72/mds581/bluelink-gdata}
mkdir -p "$OUT"
for v in ${VARS:-mld temp salt}; do
  echo "== $v"
  $RUN python3 tools/kerchunk_remap.py "$SRC/bluelink-daily-$v/kerchunk" "$OUT/bluelink-daily-$v/kerchunk" --check
done
