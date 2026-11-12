## Full run: chlorophyll vs days since retreat, one table per ice year.
##
##   Rscript scripts/run_chl_dsr.R [first=1997] [last=2025] [outdir=~/trend-ice-chl] [cores=4]
##
## For each ice year: retreat layer from Acacia, every 5-day composite with
## mid-date Sep 1 .. Apr 30, regridded to the ice grid, rows in dsr -30..120.
## Writes chl_dsr_<year>.parquet (or .csv.gz without arrow) and appends to
## log.csv. Years already written are skipped, so it can be restarted.

source("R/read_iceseason.R")
source("R/chl_on_icegrid.R")
suppressPackageStartupMessages(library(terra))

args <- commandArgs(trailingOnly = TRUE)
first <- if (length(args) >= 1) as.integer(args[1]) else 1997L
last <- if (length(args) >= 2) as.integer(args[2]) else 2025L
outdir <- path.expand(if (length(args) >= 3) args[3] else "~/trend-ice-chl")
cores <- if (length(args) >= 4) as.integer(args[4]) else 4L
dir.create(outdir, showWarnings = FALSE, recursive = TRUE)
has_arrow <- requireNamespace("arrow", quietly = TRUE)
ext <- if (has_arrow) "parquet" else "csv.gz"

iceseason_acacia()
logfile <- file.path(outdir, "log.csv")
logrow <- function(...) {
  d <- data.frame(..., time = format(Sys.time()))
  write.table(d, logfile, sep = ",", row.names = FALSE,
              col.names = !file.exists(logfile), append = TRUE)
}

for (year in first:last) {
  out <- file.path(outdir, sprintf("chl_dsr_%d.%s", year, ext))
  if (file.exists(out)) { message(year, ": exists, skipping"); next }
  ret <- tryCatch(read_iceseason("retreat", year)[[1]], error = function(e) NULL)
  if (is.null(ret)) { logrow(year = year, status = "no retreat layer", ncomp = 0L, nrow = 0L); next }
  f <- tryCatch(chl_files(c(year, year + 1L)), error = function(e) NULL)
  if (!is.null(f)) {
    f <- f[f$mid >= as.Date(sprintf("%d-09-01", year)) &
           f$mid <= as.Date(sprintf("%d-04-30", year + 1L)), ]
  }
  if (is.null(f) || !nrow(f)) { logrow(year = year, status = "no chl files", ncomp = 0L, nrow = 0L); next }
  message(year, ": ", nrow(f), " composites")
  ## terra objects do not cross forks; each worker reads retreat itself
  ret_file <- tempfile(fileext = ".tif"); writeRaster(ret, ret_file)
  one <- function(i) {
    tryCatch({
      r <- rast(ret_file)
      chl_dsr_table(chl_on_icegrid(f$file[i], template = r), r, f$mid[i], year)
    }, error = function(e) {
      message("  failed ", basename(f$file[i]), ": ", conditionMessage(e)); NULL
    })
  }
  parts <- if (cores > 1L) parallel::mclapply(seq_len(nrow(f)), one, mc.cores = cores)
           else lapply(seq_len(nrow(f)), one)
  nfail <- sum(vapply(parts, is.null, logical(1)))
  tab <- do.call(rbind, parts)
  if (is.null(tab)) tab <- data.frame(cell = integer(), ice_year = integer(), mid = as.Date(character()),
                                      dsr = integer(), log10chl = numeric(), n = numeric())
  if (has_arrow) arrow::write_parquet(tab, out) else utils::write.csv(tab, gzfile(out), row.names = FALSE)
  logrow(year = year, status = if (nfail) sprintf("%d composites failed", nfail) else "ok",
         ncomp = nrow(f), nrow = nrow(tab))
  unlink(ret_file)
}
message("done")
