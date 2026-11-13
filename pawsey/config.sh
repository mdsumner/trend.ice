## shared settings for the trend.ice grist deployment on Setonix, sourced
## by every script in pawsey/. Work files (catalog, mapping, sums) live
## in WORK, outside the repo; the repo only holds code and site outputs.
REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
WORK=${WORK:-/scratch/pawsey1362/$USER/trend-ice-s2}
mkdir -p "$WORK"

## the source: NSIDC CDR G02202 v6 daily south, through the published
## index (mdim VRT over the original netCDF files) and its grist catalog
SRC=${SRC:-cdr-sic}                      # grist source name (fraction 0-1)
TRANSFORM=${TRANSFORM:-unit_interval}    # drops CDR flags (2.51..2.55)
## the index exposes x/y but not the CDR grid mapping, so the CRS is given
## here: NSIDC Sea Ice Polar Stereographic South (as the ice season COGs)
CRS=${CRS:-EPSG:3412}
CATALOG_URL=${CATALOG_URL:-https://data.source.coop/ausantarctic/ausantarctic-scratch/seaice/g02202-v6-daily-south/grist/catalog.parquet}
BUCKET=${BUCKET:-pawsey1197:aad-derived/trend-ice/s2}   # sums published here
REGISTRY_URL=${REGISTRY_URL:-https://projects.pawsey.org.au/aad-derived/trend-sst/s2_registry.parquet}

## Setonix modules: singularity/4.1.0-slurm needs pawseyenv/2024.05, and a
## non-login shell needs Lmod first (as trend.chl)
if ! type module >/dev/null 2>&1; then _u=${-//[^u]/}; set +u; source /etc/profile; [ -n "$_u" ] && set -u; fi
module load pawseyenv/2024.05 singularity/4.1.0-slurm
command -v singularity >/dev/null || { echo "singularity not found after module load" >&2; exit 1; }
export RUN=${RUN:-"singularity exec $MYSOFTWARE/sif_lib/gdal-r-python-extras_2026-10-25.sif"}
## grist from the mdim-projected branch goes in its OWN library, first on
## the path, so trend.sst/sla/chl keep the grist they were validated with
export ICE_LIB=${ICE_LIB:-$MYSOFTWARE/r-lib-trend-ice}
export R_LIBS_USER=$ICE_LIB:${R_LIBS_USER_BASE:-$MYSOFTWARE/r-lib}
GRIST_REF=${GRIST_REF:-hypertidy/grist@mdim-projected}
## per-worker GDAL limits (lessons from trend.sla)
export GDAL_CACHEMAX=256
export GDAL_PAM_ENABLED=NO
export GDAL_DISABLE_READDIR_ON_OPEN=EMPTY_DIR
export GDAL_LOAD_EXTRA_DIM_METADATA_DELAY=0
## parallel workers for the backfill, independent of the CPUs allocated:
## each worker holds R + arrow + GDAL + the parsed index; set from
## pawsey/memprobe.sh (workers ~ 0.8 * job memory / per-worker MB)
WORKERS=${WORKERS:-12}
export SRC TRANSFORM CRS WORK REPO WORKERS
