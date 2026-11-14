#!/bin/bash --login
#SBATCH --job-name=ice-verify
#SBATCH --account=pawsey1362
#SBATCH --partition=work
#SBATCH --nodes=1 --ntasks=1 --cpus-per-task=2 --mem=16G --time=01:00:00
#SBATCH --output=%x-%j.out
## recompute N random finished dates in ONE process (no workers) and
## compare with the stored sums exactly: guards against any corruption
## from the worker crashes seen in the backfill log.
##   sbatch pawsey/verify.sh [N=40] [cdr|asi]
set -eu
[ -n "${2:-}" ] && export ICE_SOURCE=$2
cd "${SLURM_SUBMIT_DIR:-$PWD}"
source pawsey/config.sh
cd "$WORK"
export NVERIFY=${1:-40}
$RUN Rscript - <<'R'
library(arrow); library(grist)
reg <- read_parquet("s2_registry.parquet")
files <- read_parquet(Sys.getenv("CAT"))
src <- stat_source(Sys.getenv("SRC"), files, transform = Sys.getenv("TRANSFORM"),
                   grid = if (nzchar(Sys.getenv("CRS"))) list(projection = Sys.getenv("CRS")) else NULL)
done <- sub("\\.parquet$", "", list.files(file.path("sums", src$name), "\\.parquet$"))
set.seed(1)
pick <- sample(done, min(length(done), as.integer(Sys.getenv("NVERIFY"))))
cat(sprintf("%i dates done; verifying %i\n", length(done), length(pick)))
bad <- 0L
for (d in pick) {
  i <- match(as.Date(d), as.Date(src$files$date))
  new <- read_parquet(accumulate_date(src$files$dsn[i], src$files$date[i], src, reg,
                                      out_path = "verify-sums", overwrite = TRUE))
  old <- read_parquet(file.path("sums", src$name, paste0(d, ".parquet")))
  ok <- nrow(new) == nrow(old) && identical(new$cell, old$cell) &&
    max(abs(as.matrix(new[c("n", "sumw", "sumwx", "sumwx2")]) -
            as.matrix(old[c("n", "sumw", "sumwx", "sumwx2")]))) == 0
  if (!ok) { bad <- bad + 1L; cat("MISMATCH", d, "\n") }
}
cat(sprintf("VERIFY %i of %i identical\n", length(pick) - bad, length(pick)))
R
rm -rf verify-sums
