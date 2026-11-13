## BRAN 5-day composites (scripts/bran_composites.py output) onto the ice grid,
## as a table to join with the chl tables on (cell, mid).
##
##   Rscript scripts/bran_to_icegrid.R [indir=bran5day] [outdir=bran_icegrid]
##
## Per year writes bran_icegrid_<year>.parquet (csv.gz without arrow):
##   cell, mid (= composite start + 2), mld, temp, salt  (cell means, average
##   resampling onto the 25 km EPSG:3412 grid; ocean cells only)
## Only composites with mid-date Sep 1 .. Apr 30 (the chl season) are kept.

source("R/chl_on_icegrid.R")
suppressPackageStartupMessages(library(terra))

args <- commandArgs(trailingOnly = TRUE)
indir <- path.expand(if (length(args) >= 1) args[1] else "bran5day")
outdir <- path.expand(if (length(args) >= 2) args[2] else "bran_icegrid")
dir.create(outdir, showWarnings = FALSE, recursive = TRUE)
has_arrow <- requireNamespace("arrow", quietly = TRUE)
ext <- if (has_arrow) "parquet" else "csv.gz"

template <- ice_grid()

bran_year_table <- function(f, template) {
  vars <- c("mld", "temp", "salt")
  r <- lapply(vars, function(v) rast(sprintf('NETCDF:"%s":%s', f, v)))
  names(r) <- vars
  starts <- as.Date(time(r$mld))
  if (anyNA(starts)) {
    ## fall back to the composite calendar if GDAL did not decode time
    y <- as.integer(sub(".*bran_5day_([0-9]{4})\\.nc$", "\\1", f))
    starts <- as.Date(sprintf("%d-01-01", y)) + 5L * (seq_len(nlyr(r$mld)) - 1L)
  }
  ## lon -180..180, lat south of 48S; the target grid is fully specified
  g <- lapply(r, function(x) {
    crs(x) <- "EPSG:4326"
    project(x, template, method = "average")
  })
  v <- lapply(g, values)
  n <- ncell(template)
  out <- data.frame(cell = rep(seq_len(n), nlyr(r$mld)),
                    mid = rep(starts + 2L, each = n),
                    mld = as.vector(v$mld), temp = as.vector(v$temp), salt = as.vector(v$salt))
  mon <- as.integer(format(out$mid, "%m"))
  out[(!is.na(out$mld) | !is.na(out$temp)) & (mon >= 9L | mon <= 4L), ]
}

files <- list.files(indir, pattern = "^bran_5day_[0-9]{4}\\.nc$", full.names = TRUE)
for (f in files) {
  y <- sub(".*bran_5day_([0-9]{4})\\.nc$", "\\1", f)
  out <- file.path(outdir, sprintf("bran_icegrid_%s.%s", y, ext))
  if (file.exists(out)) { message(y, ": exists"); next }
  tab <- bran_year_table(f, template)
  if (has_arrow) arrow::write_parquet(tab, out) else utils::write.csv(tab, gzfile(out), row.names = FALSE)
  message(y, ": ", nrow(tab), " rows")
}
