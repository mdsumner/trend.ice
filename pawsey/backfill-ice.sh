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
## are done. ~17,500 small reads (316 x 332 each) through the index.
set -eu
cd "${SLURM_SUBMIT_DIR:-$PWD}"
bash pawsey/catalog.sh
source pawsey/config.sh
cd "$WORK"
[ -f "mapping/$SRC/meta.rds" ] || { echo "no mapping: run pawsey/onboard-ice.sh first" >&2; exit 1; }
$RUN Rscript - <<'R'
library(arrow)      # FIRST, before anything loads GDAL
library(grist)
reg <- read_parquet("s2_registry.parquet")
files <- read_parquet("icefiles.parquet")
src <- stat_source(Sys.getenv("SRC"), files, transform = Sys.getenv("TRANSFORM"),
                   grid = list(projection = Sys.getenv("CRS")))
## workers are recycled every CHUNK dates (fresh processes per chunk): the
## first full run at 54 workers grew steadily to 96 GB over 70 min (a
## per-date leak in the read path), so no worker lives long enough for it
## to matter. Each chunk starts and stops its own mirai daemons.
chunk <- as.integer(Sys.getenv("CHUNK", "1000"))
todo <- plan_dates(src)
message(sprintf("[%s] %i of %i dates to do, in chunks of %i", src$name,
                nrow(todo), nrow(src$files), chunk))
keep <- which(as.Date(src$files$date) %in% todo$date)
for (k in split(keep, ceiling(seq_along(keep) / chunk))) {
  s1 <- src; s1$files <- src$files[k, ]
  backfill(s1, reg, workers = as.integer(Sys.getenv("WORKERS", "12")))
  gc()
}
R
module load rclone/1.68.1
rclone copy --checksum sums/ $BUCKET/sums/ || echo "WARNING: sums copy FAILED" >&2
rclone copy --checksum mapping/ $BUCKET/mapping/ || echo "WARNING: mapping copy FAILED" >&2
for f in s2_registry.parquet icefiles.parquet; do
  rclone copyto --checksum $f $BUCKET/$f || echo "WARNING: $f copy FAILED" >&2
done
$RUN Rscript -e 'grist::write_manifest(".")' \
  && rclone copyto manifest.json $BUCKET/manifest.json \
  || echo "WARNING: manifest FAILED" >&2
