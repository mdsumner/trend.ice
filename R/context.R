## context.R
##
## Context for the chl vs retreat tables, to separate the effect of retreat
## from season, place and ice-edge contamination:
##
##   cell_context()      per-cell lon, lat, sector (and depth if a bathymetry
##                       source is given) on the ice grid
##   ice_window()        ice concentration over a composite's 5 days:
##                       max in the cell, and max in the 3x3 neighbourhood
##                       (~75 km), both in percent
##   openwater_summary() chl in cells with no ice that year (daycount 0),
##                       summarised by 1-degree latitude band and sector: the
##                       seasonal baseline without any retreat

sector_levels <- c("Weddell", "Indian", "W Pacific", "Ross", "Bell-Amundsen")

## Weddell 60W-20E, Indian 20E-90E, W Pacific 90E-160E, Ross 160E-130W,
## Bellingshausen-Amundsen 130W-60W
sector_of <- function(lon) {
  l <- (lon + 360) %% 360
  s <- cut(l, c(0, 20, 90, 160, 230, 300, 360), right = FALSE,
           labels = c("Weddell", "Indian", "W Pacific", "Ross", "Bell-Amundsen", "Weddell2"))
  s <- as.character(s)
  s[s == "Weddell2"] <- "Weddell"
  factor(s, levels = sector_levels)
}

## bathy: optional GDAL source of elevation (negative below sea level), e.g.
## a GEBCO COG or VRT; averaged onto the grid
cell_context <- function(template, bathy = NULL) {
  cell <- seq_len(terra::ncell(template))
  xy <- terra::xyFromCell(template, cell)
  ll <- terra::project(xy, from = terra::crs(template), to = "EPSG:4326")
  out <- data.frame(cell = cell, lon = ll[, 1], lat = ll[, 2], sector = sector_of(ll[, 1]))
  if (!is.null(bathy)) {
    b <- terra::project(terra::rast(bathy), template, method = "average")
    out$depth <- terra::values(b)[, 1]
  }
  out
}

## dates: the days of the composite. reader(dates) must return a SpatRaster
## of concentration on the template grid (0-1 or 0-100), one layer per date.
ice_window <- function(dates, template, reader = NULL) {
  if (is.null(reader)) {
    reader <- function(d) raadtools::readice(d, hemisphere = "south", setNA = TRUE)
  }
  x <- reader(dates)
  if (!inherits(x, "SpatRaster")) x <- terra::rast(x)
  m <- terra::values(x, mat = TRUE)
  vmax <- suppressWarnings(max(m, na.rm = TRUE))
  if (is.finite(vmax) && vmax <= 1.0001) m <- m * 100
  m[m > 100] <- NA
  mx <- suppressWarnings(apply(m, 1, max, na.rm = TRUE))
  mx[!is.finite(mx)] <- NA
  r <- terra::rast(template, nlyrs = 1)
  terra::values(r) <- mx
  near <- terra::focal(r, w = 3, fun = "max", na.rm = TRUE)
  out <- c(r, near)
  names(out) <- c("ice_max", "ice_near")
  out
}

## chl: output of chl_on_icegrid(); daycount: the ice season daycount layer
## for the ice year (0 = never at/above threshold); ctx: cell_context()
openwater_summary <- function(chl, daycount, ctx, mid, ice_year, min_n = 1) {
  v <- terra::values(chl)
  dc <- terra::values(daycount)[, 1]
  keep <- which(!is.na(dc) & dc == 0 & !is.na(v[, "log10chl"]) & v[, "n"] >= min_n)
  if (!length(keep)) return(NULL)
  d <- data.frame(lat_band = floor(ctx$lat[keep]), sector = ctx$sector[keep],
                  log10chl = v[keep, "log10chl"])
  a <- stats::aggregate(d$log10chl, d[c("lat_band", "sector")], function(x)
    c(q25 = unname(stats::quantile(x, 0.25)), med = stats::median(x),
      q75 = unname(stats::quantile(x, 0.75)), ncell = length(x)))
  out <- data.frame(ice_year = as.integer(ice_year), mid = mid,
                    a[c("lat_band", "sector")], a$x)
  out$ncell <- as.integer(out$ncell)
  out
}
