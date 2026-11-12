## ice_season.R
##
## Southern Ocean sea ice seasonality (day of advance, day of retreat,
## duration, day count) per pixel per ice year, after Massom et al. (2013).
##
## Rewrite of aceecostats::calc_ice_season() (AustralianAntarcticDivision/aceecostats,
## R/calc-ice-season.R) with these changes:
##
##  * pixels with ice on the last day of the ice year get retreat = NA
##    ("did not retreat"); the old code set these to 1 via length(year_n)
##  * advance is the first day of the first run of >= ndays at/above threshold
##    and retreat is the first ice-free day after the last ice day
##    (the old code was one day early for both)
##  * day count uses the same >= threshold test as advance/retreat
##  * the ice year is exactly Feb 15 .. Feb 14 (365 or 366 days)
##  * a season with an observation gap longer than max_gap days is not
##    computed (all NA) rather than interpolated across (e.g. 1987-12 to 1988-01)
##  * shorter gaps (the two-daily early record) are linearly interpolated
##  * retreat is only defined where there was an ice season (an advance), so
##    isolated ice days in open water do not produce a retreat
##  * dates whose field is mostly empty are treated as missing observations
##    (dropped before interpolation), not as open water
##  * flags ice_at_start / ice_at_end and n_missing are written alongside, so
##    perennial-ice pixels can be excluded downstream rather than encoded
##    in the values
##
## Day numbers are day of the ice year: day 1 = Feb 15.
##
## Usage (on the box that sees the ice data):
##   Rscript ice_season.R <first_year> <last_year> [threshold=15] [outdir=iceseason_v2]
## e.g.
##   Rscript ice_season.R 1979 2025 15 /path/to/iceseason_v2
##
## Output: one COG per ice year, 7 Int16 layers, plus manifest.csv.

## ---- core (pure base R, no IO) ---------------------------------------------

ice_year_dates <- function(year, mon = 2L, mday = 15L) {
  start <- as.Date(sprintf("%04d-%02d-%02d", year, mon, mday))
  end <- seq(start, by = "1 year", length.out = 2L)[2L] - 1L
  seq(start, end, by = "1 day")
}

## Linear interpolation along time for every cell at once.
## m: ncell x nobs matrix of concentration (%), obs_dates: Date (sorted, unique)
## Returns ncell x length(dates), or NULL if any gap exceeds max_gap days
## (gaps at either end of the year count too).
fill_daily <- function(m, obs_dates, dates, max_gap = 5L) {
  stopifnot(ncol(m) == length(obs_dates))
  od <- as.numeric(obs_dates)
  td <- as.numeric(dates)
  if (length(od) < 2L) return(NULL)
  gap <- max(c(diff(od) - 1, od[1L] - td[1L], td[length(td)] - od[length(od)]))
  if (gap > max_gap) return(NULL)
  if (length(od) == length(td) && all(od == td)) return(m)
  j <- findInterval(td, od, all.inside = TRUE)
  w <- (td - od[j]) / (od[j + 1L] - od[j])
  w <- pmin(pmax(w, 0), 1)  ## clamp: constant beyond the ends (approx rule = 2)
  nr <- nrow(m)
  m[, j, drop = FALSE] * rep(1 - w, each = nr) + m[, j + 1L, drop = FALSE] * rep(w, each = nr)
}

## m: ncell x nday matrix of daily concentration (%) for one ice year,
##    NA for land or missing.
## Returns a data.frame with one row per cell.
ice_season <- function(m, threshold = 15, ndays = 5L) {
  nd <- ncol(m)
  n_missing <- rowSums(is.na(m))
  land <- n_missing == nd
  ice <- m >= threshold
  ice[is.na(ice)] <- FALSE
  any_ice <- rowSums(ice) > 0L

  ## run[, d] is TRUE when days d .. d + ndays - 1 are all ice
  nrun <- nd - ndays + 1L
  run <- ice[, seq_len(nrun), drop = FALSE]
  for (k in seq_len(ndays - 1L)) run <- run & ice[, k + seq_len(nrun), drop = FALSE]
  has_run <- rowSums(run) > 0L

  advance <- max.col(run, ties.method = "first")
  advance[!has_run] <- NA_integer_

  last_ice <- max.col(ice, ties.method = "last")
  ice_at_end <- ice[, nd]
  retreat <- last_ice + 1L
  retreat[!any_ice | ice_at_end] <- NA_integer_
  ## no ice season (no run of ndays), no retreat: stops isolated ice days
  ## (weather effects in open water, coastal spillover) producing a retreat
  retreat[!has_run] <- NA_integer_

  out <- data.frame(
    advance = as.integer(advance),
    retreat = as.integer(retreat),
    duration = as.integer(retreat - advance),
    daycount = as.integer(rowSums(ice)),
    ice_at_start = as.integer(ice[, 1L]),
    ice_at_end = as.integer(ice_at_end),
    n_missing = as.integer(n_missing)
  )
  out[land, ] <- NA_integer_
  out
}

## ---- IO --------------------------------------------------------------------

## Swap this function to read from the ice index (zaro / ndr / icechunkr)
## instead of raadtools; it must return the matrix (ncell x nobs, %), the
## observation dates, and a single-layer SpatRaster template for the grid.
read_ice_obs <- function(dates, hemisphere = "south") {
  files <- raadtools::icefiles(hemisphere = hemisphere)
  files <- files[as.Date(files$date) >= min(dates) & as.Date(files$date) <= max(dates), ]
  files <- files[!duplicated(as.Date(files$date)), ]
  if (nrow(files) < 2L) return(NULL)
  obs_dates <- as.Date(files$date)
  x <- raadtools::readice(files$date, hemisphere = hemisphere, setNA = TRUE)
  if (!inherits(x, "SpatRaster")) x <- terra::rast(x)
  m <- terra::values(x, mat = TRUE)
  ## concentration must be percent; some products (e.g. NSIDC-0051 netCDF)
  ## come as a fraction 0-1
  vmax <- max(m, na.rm = TRUE)
  if (is.finite(vmax) && vmax <= 1.0001) {
    message("ice concentration looks like a fraction (max ", vmax, "), scaling to percent")
    m <- m * 100
  }
  m[m > 100] <- NA  ## flag values, if any survive setNA
  ## a date whose field is (mostly) empty is a missing observation, not a day
  ## of open water: drop it so fill_daily() interpolates or the gap rule applies
  nvalid <- colSums(!is.na(m))
  keep <- nvalid >= 0.5 * stats::median(nvalid)
  if (sum(keep) < 2L) return(NULL)
  list(m = m[, keep, drop = FALSE], obs_dates = obs_dates[keep], template = x[[1L]],
       vrange = range(m, na.rm = TRUE), ndropped = sum(!keep))
}

run_year <- function(year, threshold = 15, outdir = "iceseason_v2",
                     hemisphere = "south", max_gap = 5L, ndays = 5L) {
  dates <- ice_year_dates(year)
  fname <- file.path(outdir, sprintf("%s_iceseason_t%02d_%s.tif", hemisphere,
                                     as.integer(threshold), format(dates[1L])))
  obs <- read_ice_obs(dates, hemisphere = hemisphere)
  status <- "ok"
  if (is.null(obs)) {
    status <- "no data"
  } else {
    m <- fill_daily(obs$m, obs$obs_dates, dates, max_gap = max_gap)
    if (is.null(m)) {
      status <- "gap > max_gap, not computed"
    } else {
      s <- ice_season(m, threshold = threshold, ndays = ndays)
      r <- terra::rast(obs$template, nlyrs = ncol(s))
      terra::values(r) <- as.matrix(s)
      names(r) <- names(s)
      terra::writeRaster(r, fname, filetype = "COG", datatype = "INT2S",
                         NAflag = -32768, overwrite = TRUE,
                         gdal = c("COMPRESS=ZSTD", "PREDICTOR=2"))
    }
  }
  data.frame(year = year, start = format(dates[1L]), end = format(dates[length(dates)]),
             threshold = threshold, nobs = if (is.null(obs)) 0L else length(obs$obs_dates),
             ndropped = if (is.null(obs)) NA_integer_ else obs$ndropped,
             vmin = if (is.null(obs)) NA_real_ else obs$vrange[1L],
             vmax = if (is.null(obs)) NA_real_ else obs$vrange[2L],
             status = status, file = if (status == "ok") basename(fname) else NA_character_)
}

## ---- driver ----------------------------------------------------------------

if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) < 2L) stop("usage: Rscript ice_season.R first_year last_year [threshold] [outdir]")
  years <- seq(as.integer(args[1L]), as.integer(args[2L]))
  threshold <- if (length(args) >= 3L) as.numeric(args[3L]) else 15
  outdir <- if (length(args) >= 4L) args[4L] else "iceseason_v2"
  dir.create(outdir, showWarnings = FALSE, recursive = TRUE)
  manifest <- do.call(rbind, lapply(years, function(y) {
    message(y)
    run_year(y, threshold = threshold, outdir = outdir)
  }))
  write.csv(manifest, file.path(outdir, sprintf("manifest_t%02d.csv", as.integer(threshold))),
            row.names = FALSE)
  print(manifest)
}
