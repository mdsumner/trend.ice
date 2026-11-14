#!/bin/bash --login
#SBATCH --job-name=ice-memprobe
#SBATCH --account=pawsey1362
#SBATCH --partition=work
#SBATCH --nodes=1 --ntasks=1 --cpus-per-task=2 --mem=32G --time=00:30:00
#SBATCH --output=%x-%j.out
## one worker's memory and time across 10 dates (as trend.sla's probe):
## flat after date 1 = fixed per-worker cost, so workers = memory / that;
## climbing = a leak. From the repo root:  sbatch pawsey/memprobe.sh
set -eu
[ $# -ge 1 ] && export ICE_SOURCE=$1
cd "${SLURM_SUBMIT_DIR:-$PWD}"
source pawsey/config.sh
cd "$WORK"
$RUN Rscript - <<'R'
library(arrow); library(grist)
rss <- function() as.numeric(gsub("[^0-9]+", "", grep("^VmRSS",
                  readLines("/proc/self/status"), value = TRUE))) / 1024
reg <- read_parquet("s2_registry.parquet")
files <- read_parquet(Sys.getenv("CAT"))
cat(sprintf("after loading packages + catalog: %.0f MB\n", rss()))
t <- system.time(src <- stat_source(Sys.getenv("SRC"), files, transform = Sys.getenv("TRANSFORM"),
                                    grid = if (nzchar(Sys.getenv("CRS"))) list(projection = Sys.getenv("CRS")) else NULL))[3]
cat(sprintf("after stat_source (resolve 17531 views): %.0f MB, %.1f s\n", rss(), t))
for (i in c(1, 2, 5000, 5001, 11648, 11649, 15000, 15001, 17000, 17001)) {
  t <- system.time(accumulate_date(src$files$dsn[i], src$files$date[i], src, reg,
                   out_path = "probe-sums", overwrite = TRUE))[3]
  cat(sprintf("date %s: %.0f MB after, %.1f s\n", format(src$files$date[i]), rss(), t))
}
R
rm -rf probe-sums
