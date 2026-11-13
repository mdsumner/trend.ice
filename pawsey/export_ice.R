## Per-cell sea ice trends from the grist sums, as a site export in the
## same schema as the trend.* cells-*.json (id, ring, mean, trend, lon,
## lat), so scripts/s2_trend_maps.R draws it like the other records.
##   Rscript pawsey/export_ice.R WORK OUT_JSON [first=1979] [last=2025]
## trend: least-squares slope of the annual mean concentration (all days
## of the calendar year, area weighted), in percent concentration per
## decade; mean: the same over all years, percent. Cells need annual
## means in >= 80% of the years.
suppressPackageStartupMessages({ library(arrow); library(dplyr) })
args <- commandArgs(trailingOnly = TRUE)
work <- args[1]; out <- args[2]
y0 <- if (length(args) >= 3) as.integer(args[3]) else 1979L
y1 <- if (length(args) >= 4) as.integer(args[4]) else 2025L
src <- Sys.getenv("SRC", "cdr-sic")
reg <- read_parquet(file.path(work, "s2_registry.parquet"))
p <- file.path(work, "sums", src)
d0 <- as.Date(sprintf("%i-01-01", y0)); d1 <- as.Date(sprintf("%i-12-31", y1))

ann <- open_dataset(p) |>
  filter(date >= d0, date <= d1) |>
  mutate(year = lubridate::year(date)) |>
  group_by(cell, year) |>
  summarise(sumw = sum(sumw), sumwx = sum(sumwx)) |>
  collect() |>
  mutate(m = sumwx / sumw)
years <- y0:y1
percell <- ann |> group_by(cell) |>
  summarise(n_years = n(),
            mean = 100 * sum(sumwx) / sum(sumw),
            trend = if (n() >= 0.8 * length(years)) 1000 * coef(lm(m ~ year))[[2]] else NA_real_,
            .groups = "drop") |>
  filter(!is.na(trend))
message(sprintf("%s: %i cells with a trend, %i-%i", src, nrow(percell), y0, y1))

## slerp-densified cell rings, as trend.chl's export
xyz <- function(lon, lat) c(cos(lat * pi/180) * cos(lon * pi/180),
                            cos(lat * pi/180) * sin(lon * pi/180), sin(lat * pi/180))
slerp <- function(a, b, n = 8) {
  t <- seq(0, 1, length.out = n)
  ang <- acos(max(-1, min(1, sum(a * b))))
  w1 <- sin((1 - t) * ang) / sin(ang); w2 <- sin(t * ang) / sin(ang)
  cbind(w1 * a[1] + w2 * b[1], w1 * a[2] + w2 * b[2], w1 * a[3] + w2 * b[3])
}
ring_of <- function(cell) {
  vs <- lapply(0:3, function(k) {
    pt <- s2::s2_cell_vertex(s2::s2_cell(cell), k)
    xyz(s2::s2_x(pt), s2::s2_y(pt))
  })
  pts <- do.call(rbind, lapply(1:4, function(i) slerp(vs[[i]], vs[[i %% 4 + 1]])))
  ll <- cbind(atan2(pts[, 2], pts[, 1]) * 180/pi, asin(pmax(-1, pmin(1, pts[, 3]))) * 180/pi)
  round(ll[!duplicated(round(ll, 5)), , drop = FALSE], 2)
}
ii <- match(percell$cell, reg$cell)
cells <- lapply(seq_len(nrow(percell)), function(i)
  list(id = percell$cell[i], ring = ring_of(percell$cell[i]),
       mean = round(percell$mean[i], 2), trend = round(percell$trend[i], 3),
       lon = round(reg$lon[ii[i]], 2), lat = round(reg$lat[ii[i]], 2)))
dir.create(dirname(out), showWarnings = FALSE, recursive = TRUE)
jsonlite::write_json(list(source = src, years = c(y0, y1),
                          units = list(mean = "percent", trend = "percent / decade"),
                          cells = cells),
                     out, auto_unbox = TRUE, digits = NA)
message("wrote ", out)
