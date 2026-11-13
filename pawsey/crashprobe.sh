#!/bin/bash --login
#SBATCH --job-name=ice-crashprobe
#SBATCH --account=pawsey1362
#SBATCH --partition=work
#SBATCH --nodes=1 --ntasks=1 --cpus-per-task=2 --mem=16G --time=01:00:00
#SBATCH --output=%x-%j.out
## do the free() crashes reproduce in ONE process? Two loops of open /
## read / close over 300 dates with gc() every iteration:
##   A: exactly as grist does it (ds$close(), then the object is dropped)
##   B: no explicit close (R's finalizer only)
## A crash in A but not B points at a double close of the mdim view; a
## crash in both points at the two Arrow copies (R arrow + GDAL's) in one
## process; no crash points at the parallel setting (mirai workers).
##   sbatch pawsey/crashprobe.sh
set -eu
cd "${SLURM_SUBMIT_DIR:-$PWD}"
source pawsey/config.sh
cd "$WORK"
for MODE in A B; do
  echo "== mode $MODE"
  MODE=$MODE $RUN Rscript - <<'R' || echo "mode $MODE: process died (exit $?)"
library(arrow); library(grist)
files <- read_parquet("icefiles.parquet")
src <- stat_source(Sys.getenv("SRC"), files[1:400, ], transform = Sys.getenv("TRANSFORM"),
                   grid = list(projection = Sys.getenv("CRS")))
mode <- Sys.getenv("MODE")
for (i in 1:300) {
  ds <- grist:::mdim_open(src$files$dsn[i], src$files$array[i], src$files$view[i])
  v <- ds$read(1L, 0L, 0L, 316L, 332L, 316L, 332L)
  if (mode == "A") ds$close()
  rm(ds); gc()
  if (i %% 50 == 0) cat(sprintf("mode %s: %i ok\n", mode, i))
}
cat(sprintf("mode %s: completed 300\n", mode))
R
done
