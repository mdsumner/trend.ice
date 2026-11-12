## read_iceseason.R
##
## Read one ice season variable across years as a single SpatRaster
## (one layer per ice year, time = ice year start date). Bespoke access to the
## trend.ice COGs; a proper virtual index is left for raad.virtualize.
##
##   source("R/read_iceseason.R")
##   ret <- read_iceseason("retreat")                    # all years, from Acacia
##   ret <- read_iceseason("retreat", 1997:2025, src = "~/iceseason_v2")
##
## Variables: advance, retreat, duration, daycount, ice_at_start, ice_at_end,
## n_missing. Day numbers are day of the ice year (day 1 = Feb 15).

iceseason_vars <- c("advance", "retreat", "duration", "daycount",
                    "ice_at_start", "ice_at_end", "n_missing")

## Acacia access for /vsis3/ (pawsey1197 profile); call once per session
iceseason_acacia <- function(profile = "pawsey1197") {
  Sys.setenv(AWS_PROFILE = profile,
             AWS_S3_ENDPOINT = "projects.pawsey.org.au",
             AWS_VIRTUAL_HOSTING = "NO")
  invisible(NULL)
}

iceseason_files <- function(years = NULL, threshold = 15,
                            src = "/vsis3/aad-derived/trend-ice") {
  thr <- sprintf("%02d", as.integer(threshold))
  local <- !grepl("^/vsi", src)
  dir <- if (local) path.expand(src) else file.path(src, sprintf("iceseason_t%s", thr))
  mfile <- file.path(dir, sprintf("manifest_t%s.csv", thr))
  if (!local) {
    ## fetch the manifest through GDAL's virtual file system
    tf <- tempfile(fileext = ".csv")
    if (gdalraster::vsi_copy_file(mfile, tf) != 0L) {
      stop("could not read ", mfile, " (check iceseason_acacia() settings)")
    }
    mfile <- tf
  }
  man <- utils::read.csv(mfile, stringsAsFactors = FALSE)
  man <- man[!is.na(man$file) & man$status == "ok", ]
  if (!is.null(years)) {
    miss <- setdiff(years, man$year)
    if (length(miss)) message("not available (skipped or out of range): ",
                              paste(miss, collapse = ", "))
    man <- man[man$year %in% years, ]
  }
  data.frame(year = man$year, start = as.Date(man$start),
             file = file.path(dir, man$file))
}

read_iceseason <- function(var = "retreat", years = NULL, threshold = 15,
                           src = "/vsis3/aad-derived/trend-ice") {
  var <- match.arg(var, iceseason_vars)
  if (grepl("^/vsis3/", src) && !nzchar(Sys.getenv("AWS_S3_ENDPOINT"))) iceseason_acacia()
  f <- iceseason_files(years, threshold, src)
  band <- match(var, iceseason_vars)
  x <- terra::rast(lapply(f$file, function(fl) terra::rast(fl, lyrs = band)))
  names(x) <- paste0(var, "_", f$year)
  terra::time(x) <- f$start
  x
}
