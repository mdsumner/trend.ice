## Second full run: the chl vs retreat tables with context columns, plus an
## open-water baseline.
##
##   Rscript scripts/run_chl_context.R [first=1997] [last=2025] [outdir=~/trend-ice-chl-v2] [cores=4] [bathy]
##
## Per ice year writes
##   chl_dsr_<year>.parquet    as run_chl_dsr.R plus ice_max, ice_near (percent
##                             ice over the composite's 5 days, in the cell
##                             and its 3x3 neighbourhood)
##   openwater_<year>.parquet  chl in never-iced cells by 1-degree latitude band
##                             and sector, per composite
## and once
##   cells.parquet             cell, lon, lat, sector (+ depth if bathy given)
## (csv.gz instead of parquet without arrow). Restartable; log.csv.
##
## Ice for ice_max / ice_near is read with raadtools::readice(), so run where
## the ice collection is visible.

source("R/read_iceseason.R")
source("R/chl_on_icegrid.R")
source("R/context.R")
suppressPackageStartupMessages(library(terra))

args <- commandArgs(trailingOnly = TRUE)
first <- if (length(args) >= 1) as.integer(args[1]) else 1997L
last <- if (length(args) >= 2) as.integer(args[2]) else 2025L
outdir <- path.expand(if (length(args) >= 3) args[3] else "~/trend-ice-chl-v2")
cores <- if (length(args) >= 4) as.integer(args[4]) else 4L
bathy <- if (length(args) >= 5) args[5] else NULL
dir.create(outdir, showWarnings = FALSE, recursive = TRUE)
has_arrow <- requireNamespace("arrow", quietly = TRUE)
ext <- if (has_arrow) "parquet" else "csv.gz"
write_tab <- function(x, f) {
  if (has_arrow) arrow::write_parquet(x, f) else utils::write.csv(x, gzfile(f), row.names = FALSE)
}

iceseason_acacia()
logfile <- file.path(outdir, "log.csv")
logrow <- function(...) {
  d <- data.frame(..., time = format(Sys.time()))
  if (file.exists(logfile)) {
    write.table(d, logfile, sep = ",", row.names = FALSE, col.names = FALSE, append = TRUE)
  } else {
    write.table(d, logfile, sep = ",", row.names = FALSE)
  }
}

template <- NULL
ctx <- NULL

for (year in first:last) {
  out <- file.path(outdir, sprintf("chl_dsr_%d.%s", year, ext))
  outw <- file.path(outdir, sprintf("openwater_%d.%s", year, ext))
  if (file.exists(out) && file.exists(outw)) { message(year, ": exists, skipping"); next }
  ret <- tryCatch(read_iceseason("retreat", year)[[1]], error = function(e) NULL)
  dc <- tryCatch(read_iceseason("daycount", year)[[1]], error = function(e) NULL)
  if (is.null(ret) || is.null(dc)) { logrow(year = year, status = "no ice season layer", ncomp = 0L, nrow = 0L, nopen = 0L); next }
  if (is.null(ctx)) {
    template <- rast(ret)
    ctx <- cell_context(template, bathy)
    write_tab(ctx, file.path(outdir, sprintf("cells.%s", ext)))
  }
  f <- tryCatch(chl_files(c(year, year + 1L)), error = function(e) NULL)
  if (!is.null(f)) {
    f <- f[f$mid >= as.Date(sprintf("%d-09-01", year)) &
           f$mid <= as.Date(sprintf("%d-04-30", year + 1L)), ]
  }
  if (is.null(f) || !nrow(f)) { logrow(year = year, status = "no chl files", ncomp = 0L, nrow = 0L, nopen = 0L); next }
  message(year, ": ", nrow(f), " composites")
  ret_file <- tempfile(fileext = ".tif"); writeRaster(ret, ret_file)
  dc_file <- tempfile(fileext = ".tif"); writeRaster(dc, dc_file)
  one <- function(i) {
    tryCatch({
      r <- rast(ret_file); d <- rast(dc_file)
      chl <- chl_on_icegrid(f$file[i], template = r)
      tab <- chl_dsr_table(chl, r, f$mid[i], year)
      iw <- ice_window(f$start[i] + 0:4, r)
      iv <- values(iw)
      tab$ice_max <- iv[tab$cell, "ice_max"]
      tab$ice_near <- iv[tab$cell, "ice_near"]
      list(tab = tab, open = openwater_summary(chl, d, ctx, f$mid[i], year))
    }, error = function(e) {
      message("  failed ", basename(f$file[i]), ": ", conditionMessage(e)); NULL
    })
  }
  parts <- if (cores > 1L) parallel::mclapply(seq_len(nrow(f)), one, mc.cores = cores)
           else lapply(seq_len(nrow(f)), one)
  ok <- !vapply(parts, is.null, logical(1))
  tab <- do.call(rbind, lapply(parts[ok], `[[`, "tab"))
  open <- do.call(rbind, lapply(parts[ok], `[[`, "open"))
  if (is.null(tab)) tab <- data.frame(cell = integer(), ice_year = integer(), mid = as.Date(character()),
                                      dsr = integer(), log10chl = numeric(), n = numeric(),
                                      ice_max = numeric(), ice_near = numeric())
  if (is.null(open)) open <- data.frame(ice_year = integer(), mid = as.Date(character()),
                                        lat_band = numeric(), sector = character(), q25 = numeric(),
                                        med = numeric(), q75 = numeric(), ncell = integer())
  write_tab(tab, out)
  write_tab(open, outw)
  logrow(year = year, status = if (any(!ok)) sprintf("%d composites failed", sum(!ok)) else "ok",
         ncomp = nrow(f), nrow = nrow(tab), nopen = nrow(open))
  unlink(c(ret_file, dc_file))
}
message("done")
