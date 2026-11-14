## shared settings for the trend.ice grist deployment on Setonix, sourced
## by every script in pawsey/. Work files (catalog, mapping, sums) live
## in WORK, outside the repo; the repo only holds code and site outputs.
REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
WORK=${WORK:-/scratch/pawsey1362/$USER/trend-ice-s2}
mkdir -p "$WORK"

## the source, chosen with ICE_SOURCE (default cdr). Each is read through
## its published index (mdim VRT over the original netCDF files) and the
## grist catalog published beside it. Work files are per source (catalog,
## index copies, mapping/<SRC>, sums/<SRC>), so sources sit side by side.
##   cdr: NSIDC CDR G02202 v6 daily south, 25 km, from 1978-10-25
##   asi: Bremen ASI AMSR2 v5.4 daily south, 3.125 km, from 2012-08-01
ICE_SOURCE=${ICE_SOURCE:-cdr}
SC=https://data.source.coop/ausantarctic/ausantarctic-scratch/seaice
case "$ICE_SOURCE" in
  cdr)
    SRC=${SRC:-cdr-sic}                    # grist source name (fraction 0-1)
    TRANSFORM=${TRANSFORM:-unit_interval}  # drops CDR flags (2.51..2.55)
    ## the index exposes x/y but not the CDR grid mapping: NSIDC Sea Ice
    ## Polar Stereographic South, as the ice season COGs
    CRS=${CRS-EPSG:3412}
    EXPECT_DIM=${EXPECT_DIM-316,332}
    ORACLE_DEFAULT=2010-09-15
    DSET=g02202-v6-daily-south ;;
  asi)
    SRC=${SRC:-asi-sic}
    TRANSFORM=${TRANSFORM:-percent_unit}   # 0-100 percent -> fraction
    ## the index carries no CRS either. The grid is the NSIDC south polar
    ## layout at 8x (2528 x 2656, same extent), but the source files
    ## declare it on WGS84 (+proj=stere +lat_0=-90 +lat_ts=-70 +lon_0=0
    ## +datum=WGS84), i.e. EPSG:3976, not the CDR's Hughes 1980 (3412)
    CRS=${CRS-EPSG:3976}
    EXPECT_DIM=${EXPECT_DIM-}
    ORACLE_DEFAULT=2015-09-15
    DSET=asi-amsr2-v5.4-daily-south ;;
  *) echo "unknown ICE_SOURCE '$ICE_SOURCE' (cdr or asi)" >&2; exit 1 ;;
esac
CATALOG_URL=${CATALOG_URL:-$SC/$DSET/grist/catalog.parquet}
INDEX_URL=${INDEX_URL:-$SC/$DSET/mdim.vrt}
CAT=icefiles-$SRC.parquet                  # catalog in WORK, per source
## optional mirror of the source files (a scratch copy on Acacia, path =
## the source URL's host and path, as raad keeps them). When MIRROR_TO is
## set, pawsey/remap_index.sh writes WORK/mdim-mirror-<SRC>.vrt and the catalog
## reads through it. Empty = read from NSIDC through the published index.
## The mirror keeps host + path, so one rule covers every source host
## (NSIDC CDR north/south, Bremen ASI):
##   /vsicurl/https://<host>/<path>  ->  $MIRROR_TO<host>/<path>
MIRROR_FROM=${MIRROR_FROM:-/vsicurl/https://}
## the scratch copies on Acacia (CDR north/south, Bremen ASI); set
## MIRROR_TO= (empty) to read from the original servers instead
MIRROR_TO=${MIRROR_TO-/vsicurl/https://projects.pawsey.org.au/aad-derived/raad-scratch/}
BUCKET=${BUCKET:-pawsey1197:aad-derived/trend-ice/s2}   # sums published here
REGISTRY_URL=${REGISTRY_URL:-https://projects.pawsey.org.au/aad-derived/trend-sst/s2_registry.parquet}

## Setonix modules: singularity/4.1.0-slurm needs pawseyenv/2024.05, and a
## non-login shell needs Lmod first (as trend.chl)
if ! type module >/dev/null 2>&1; then _u=${-//[^u]/}; set +u; source /etc/profile; [ -n "$_u" ] && set -u; fi
module load pawseyenv/2024.05 singularity/4.1.0-slurm
command -v singularity >/dev/null || { echo "singularity not found after module load" >&2; exit 1; }
export RUN=${RUN:-"singularity exec $MYSOFTWARE/sif_lib/gdal-r-python-extras_2026-10-25.sif"}
## grist (main, >= 0.0.2: mdim catalogs, projected grids, chunked
## backfill) goes in its OWN library, first on the path, so
## trend.sst/sla/chl keep the grist they were validated with
export ICE_LIB=${ICE_LIB:-$MYSOFTWARE/r-lib-trend-ice}
export R_LIBS_USER=$ICE_LIB:${R_LIBS_USER_BASE:-$MYSOFTWARE/r-lib}
GRIST_REF=${GRIST_REF:-hypertidy/grist}
## per-worker GDAL limits (lessons from trend.sla)
export GDAL_CACHEMAX=256
export GDAL_PAM_ENABLED=NO
export GDAL_DISABLE_READDIR_ON_OPEN=EMPTY_DIR
export GDAL_LOAD_EXTRA_DIM_METADATA_DELAY=0
## parallel workers for the backfill, independent of the CPUs allocated:
## each worker holds R + arrow + GDAL + the parsed index; set from
## pawsey/memprobe.sh (workers ~ 0.8 * job memory / per-worker MB)
WORKERS=${WORKERS:-12}
## dates per chunk; workers are fresh processes per chunk (bounds a leak)
CHUNK=${CHUNK:-1000}
export ICE_SOURCE SRC TRANSFORM CRS EXPECT_DIM ORACLE_DEFAULT CAT WORK REPO WORKERS CHUNK MIRROR_TO
