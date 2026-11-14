#!/bin/bash --login
#SBATCH --job-name=ice-backfill
#SBATCH --account=pawsey1362
#SBATCH --partition=work
#SBATCH --nodes=1 --ntasks=1 --cpus-per-task=24 --mem=96G
#SBATCH --time=08:00:00
#SBATCH --output=%x-%j.out
## refresh the catalog, backfill missing (and changed-source) dates,
## publish sums, mapping, catalog and manifest to the bucket. Workers come
## from WORKERS (pawsey/config.sh, default 12), not the CPU count: the
## first run at 54 workers on 96 GB was OOM-killed.
##   sbatch pawsey/backfill-ice.sh     # from the repo root, AFTER the oracle passed
## Resumable: rerun after any interruption and only the remaining dates
## are done. Source from ICE_SOURCE (pawsey/config.sh), e.g.
##   sbatch pawsey/backfill-ice.sh asi
set -eu
## the source as an argument (cdr|asi): Setonix jobs do not inherit the
## submitting shell's environment, so ICE_SOURCE=asi sbatch ... is lost
[ $# -ge 1 ] && export ICE_SOURCE=$1
export ICE_SOURCE=${ICE_SOURCE:-cdr}
echo "ICE_SOURCE=$ICE_SOURCE"
cd "${SLURM_SUBMIT_DIR:-$PWD}"
bash pawsey/catalog.sh
source pawsey/config.sh
cd "$WORK"
[ -f "mapping/$SRC/meta.rds" ] || { echo "no mapping: run pawsey/onboard-ice.sh first" >&2; exit 1; }
$RUN Rscript - <<'R'
library(arrow)      # FIRST, before anything loads GDAL
library(grist)
reg <- read_parquet("s2_registry.parquet")
files <- read_parquet(Sys.getenv("CAT"))
src <- stat_source(Sys.getenv("SRC"), files, transform = Sys.getenv("TRANSFORM"),
                   grid = if (nzchar(Sys.getenv("CRS"))) list(projection = Sys.getenv("CRS")) else NULL)
## workers are recycled every CHUNK dates (grist backfill(chunk =), fresh
## mirai daemons per chunk): the first full run at 54 workers grew
## steadily to 96 GB over 70 min (a per-date leak in the read path), so no
## worker lives long enough for it to matter.
backfill(src, reg, workers = as.integer(Sys.getenv("WORKERS", "12")),
         chunk = as.integer(Sys.getenv("CHUNK", "1000")))
R
module load rclone/1.68.1
rclone copy --checksum sums/ $BUCKET/sums/ || echo "WARNING: sums copy FAILED" >&2
rclone copy --checksum mapping/ $BUCKET/mapping/ || echo "WARNING: mapping copy FAILED" >&2
for f in s2_registry.parquet "$CAT"; do
  rclone copyto --checksum $f $BUCKET/$f || echo "WARNING: $f copy FAILED" >&2
done
$RUN Rscript -e 'grist::write_manifest(".")' \
  && rclone copyto manifest.json $BUCKET/manifest.json \
  || echo "WARNING: manifest FAILED" >&2
