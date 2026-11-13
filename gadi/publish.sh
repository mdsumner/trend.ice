#!/bin/bash
## Publish trend.ice outputs made on Gadi to Acacia (the home for everything
## we create). copyq: needs the network. Uses GDAL's vsi sync with the
## pawsey1197 profile from ~/.aws/credentials on Gadi.
##   qsub gadi/publish.sh                       (from the trend.ice checkout)
#PBS -q copyq
#PBS -P jk72
#PBS -l walltime=04:00:00,ncpus=1,mem=8GB,storage=gdata/jk72
#PBS -l wd

source gadi/env.sh
BASE=${BASE:-/g/data/jk72/mds581/trend-ice}
export AWS_PROFILE=${AWS_PROFILE:-pawsey1197}
export AWS_S3_ENDPOINT=projects.pawsey.org.au
export AWS_VIRTUAL_HOSTING=NO
DEST=/vsis3/aad-derived/trend-ice
for d in ${DIRS:-bran5day bran_icegrid}; do
  echo "== $d"
  $RUN gdal vsi sync --recursive "$BASE/$d/" "$DEST/$d/"
  $RUN gdal vsi list "$DEST/$d/" | tail -3
done
