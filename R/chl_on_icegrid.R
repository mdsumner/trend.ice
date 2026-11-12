## chl_on_icegrid.R
##
## ESA OC-CCI v6.0 5-day chlorophyll (4 km geographic COGs on Pawsey Acacia)
## brought onto the trend.ice sea ice grid (NSIDC south polar stereographic,
## EPSG:3412, 25 km) as the mean of log10(chl) per cell plus the count of
## valid source pixels, and aligned to sea ice retreat as days since retreat.
##
##   source("R/read_iceseason.R"); source("R/chl_on_icegrid.R")
##   f <- chl_files(2015:2016)
##   g <- chl_on_icegrid(f$file[1])          # 2 layers: log10chl, n
##
## The 5-day file date is the first day of the composite; the composite
## mid-date (start + 2 days) is used for days since retreat.

chl_root <- "/vsis3/aad-derived/esacci-oc/v6.0-release/geographic/5day/chlor_a"

## anonymous read of the aad-derived bucket
chl_acacia <- function() {
  Sys.setenv(AWS_S3_ENDPOINT = "projects.pawsey.org.au",
             AWS_NO_SIGN_REQUEST = "YES",
             AWS_VIRTUAL_HOSTING = "NO")
  invisible(NULL)
}

## the sea ice grid, matching the trend.ice COGs
ice_grid <- function() {
  terra::rast(ext = c(-3950000, 3950000, -3950000, 4350000), res = 25000,
              crs = "EPSG:3412")
}

## list 5-day chlorophyll files for calendar years
chl_files <- function(years, root = chl_root) {
  if (!nzchar(Sys.getenv("AWS_S3_ENDPOINT"))) chl_acacia()
  out <- lapply(years, function(y) {
    d <- file.path(root, y)
    fl <- gdalraster::vsi_read_dir(d)
    fl <- fl[grepl("\\.tif$", fl)]
    if (!length(fl)) return(NULL)
    data.frame(start = as.Date(sub(".*-([0-9]{8})-fv.*", "\\1", fl), "%Y%m%d"),
               file = file.path(d, fl))
  })
  out <- do.call(rbind, out)
  out$mid <- out$start + 2L
  out[order(out$start), ]
}

## regrid one 5-day file: mean log10(chl) and effective count of valid
## source pixels per 25 km cell (GDAL "sum" resampling is area weighted, so n
## is fractional). Only the source rows south of `north` are read.
chl_on_icegrid <- function(file, template = ice_grid(), north = -48) {
  x <- terra::rast(file)
  x <- terra::crop(x, terra::ext(-180, 180, -90, north))
  lx <- log10(x)
  lx[!is.finite(lx)] <- NA        ## chl <= 0 or NaN
  valid <- terra::ifel(is.na(lx), 0, 1)
  m <- terra::project(lx, template, method = "average")
  n <- terra::project(valid, template, method = "sum")
  out <- c(m, n)
  names(out) <- c("log10chl", "n")
  out
}

## ice year containing a date (ice year y runs Feb 15 y .. Feb 14 y+1)
ice_year_of <- function(date) {
  y <- as.integer(format(date, "%Y"))
  y - (date < as.Date(sprintf("%04d-02-15", y)))
}

## day of the ice year (day 1 = Feb 15)
ice_day_of <- function(date) {
  as.integer(date - as.Date(sprintf("%04d-02-15", ice_year_of(date)))) + 1L
}

## Long table for one composite: cell, ice year, days since retreat,
## log10 chl, n. retreat is the retreat layer for `ice_year`
## (e.g. read_iceseason("retreat", ice_year)[[1]]); days are counted from Feb 15
## of that ice year, so composites after Feb 14 keep counting (day > 365)
## rather than wrapping into the next ice year. Cells without a retreat, with
## fewer than min_n valid source pixels, or outside dsr_range are dropped.
## chl and retreat must be on the same grid.
chl_dsr_table <- function(chl, retreat, mid, ice_year,
                          dsr_range = c(-30L, 120L), min_n = 1) {
  day <- as.integer(mid - as.Date(sprintf("%04d-02-15", ice_year))) + 1L
  v <- cbind(terra::values(chl), retreat = terra::values(retreat)[, 1])
  dsr <- day - v[, "retreat"]
  keep <- which(!is.na(v[, "log10chl"]) & !is.na(dsr) & v[, "n"] >= min_n &
                  dsr >= dsr_range[1] & dsr <= dsr_range[2])
  data.frame(cell = keep,
             ice_year = rep(as.integer(ice_year), length(keep)),
             mid = rep(mid, length(keep)),
             dsr = as.integer(dsr[keep]),
             log10chl = v[keep, "log10chl"],
             n = v[keep, "n"])
}
