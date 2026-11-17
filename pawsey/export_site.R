## pawsey/export_site.R -- the trend.ice site data, in the schema every
## trend.* site reads with the shared kit (AustralianAntarcticDivision/
## trend kit/: explorer, status, mechanics pages).
##   Rscript pawsey/export_site.R WORK [OUT=site/data]
## WORK holds s2_registry.parquet and sums/<src>/ (the Setonix work dir,
## or a local copy of aad-derived/trend-ice/s2/). Writes into OUT:
##   status.json          per source: span, gaps
##   series.json          daily sea ice AREA (million km2) per region
##   cells-<src>.json     cell rings + per-cell metrics, preset regions,
##                        month list (also read by scripts/s2_trend_maps.R)
##   monthly-<src>.bin    Float32 cell x month mean concentration (%),
##                        cell-major
## Units: the sums are concentration as a FRACTION with pixel areas (km2)
## as weights, so sumwx is sea ice area in km2. The site shows percent.
## Cell w is the cell's mean daily ocean area (km2), so for any union of
## cells sum(w * mean) is sea ice area: the explorer's "Area" series.
## (The sst/sla/chl exporters write w = sumw / n, a mean PER-PIXEL
## weight; for a union mean the cell's ocean area is the exact weight.)
## Deliberately GDAL-free, as the sibling exporters: arrow, s2, reproj.
suppressPackageStartupMessages({ library(arrow); library(dplyr) })
args <- commandArgs(trailingOnly = TRUE)
work <- if (length(args) >= 1) args[1] else Sys.getenv("WORK")
out <- if (length(args) >= 2) args[2] else file.path("site", "data")
stopifnot(nzchar(work), dir.exists(file.path(work, "sums")))
dir.create(out, recursive = TRUE, showWarnings = FALSE)

SCALE <- 100     # fraction -> percent
TREND_PER <- 10  # per decade
DIGITS <- 2
## full calendar years for trends; baselines as each source allows
cfg <- list(
  `cdr-sic` = list(years = 1979:2025, baseline = c(1981, 2010)),
  `asi-sic` = list(years = 2013:2025, baseline = c(2013, 2022)))
cfg <- cfg[dir.exists(file.path(work, "sums", names(cfg)))]
stopifnot(length(cfg) > 0)
reg <- arrow::read_parquet(file.path(work, "s2_registry.parquet"))
iso <- function(d) format(as.Date(d))
held <- function(p) sort(as.Date(sub("\\.parquet$", "", list.files(p, "\\.parquet$"))))

## ---------------------------------------------------------------- regions
## Southern Ocean sectors as in the sea ice literature (Zwally et al.
## 1983; Parkinson & Cavalieri 2012), by cell centre longitude
cells_all <- unique(unlist(lapply(names(cfg), function(s)
  arrow::open_dataset(file.path(work, "sums", s)) |>
    distinct(cell) |> collect() |> pull(cell))))
cm <- reg[reg$cell %in% cells_all, c("cell", "lon", "lat")]
cm$sector <- with(cm, ifelse(lon >= -60 & lon < 20, "weddell",
                    ifelse(lon >= 20 & lon < 90, "indian",
                    ifelse(lon >= 90 & lon < 160, "wpac",
                    ifelse(lon >= 160 | lon < -130, "ross", "bellam")))))
region_cells <- c(
  list(so = cm$cell, so60 = cm$cell[cm$lat <= -60]),
  split(cm$cell, cm$sector)[c("weddell", "indian", "wpac", "ross", "bellam")])
region_labels <- list(
  so = "Southern Ocean (all cells)", so60 = "South of 60S",
  weddell = "Weddell Sea (60W-20E)", indian = "Indian Ocean (20E-90E)",
  wpac = "Western Pacific (90E-160E)", ross = "Ross Sea (160E-130W)",
  bellam = "Bellingshausen-Amundsen (130W-60W)")
stopifnot(all(lengths(region_cells) > 0))

## ---------------------------------------------------------------- status
status <- list(
  generated = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
  sources = lapply(names(cfg), function(s) {
    d <- held(file.path(work, "sums", s))
    list(first = iso(min(d)), last = iso(max(d)), n = length(d),
         gaps = as.list(iso(setdiff(seq(min(d), max(d), by = "1 day"), d))),
         provisional_days = 0L)
  }) |> setNames(names(cfg)))
jsonlite::write_json(status, file.path(out, "status.json"),
                     auto_unbox = TRUE, pretty = TRUE, na = "null")
message("status.json written")

## ---------------------------------------------------------------- series
## daily sea ice area (sum of sumwx, km2) per region, in million km2:
## one scan per source, cells tagged with their sector
tag <- arrow::arrow_table(data.frame(cell = cm$cell, sector = cm$sector,
                                     s60 = cm$lat <= -60))
series <- lapply(names(cfg), function(s) {
  daily <- arrow::open_dataset(file.path(work, "sums", s)) |>
    select(cell, date, sumwx) |>
    inner_join(tag, by = "cell") |>
    group_by(date, sector, s60) |>
    summarise(a = sum(sumwx)) |>
    collect()
  dates <- sort(unique(daily$date))
  tot <- function(d) {
    x <- d |> group_by(date) |> summarise(a = sum(a), .groups = "drop")
    round(x$a[match(dates, x$date)] / 1e6, 3)
  }
  o <- list(dates = iso(dates), so = tot(daily), so60 = tot(daily[daily$s60, ]))
  for (k in c("weddell", "indian", "wpac", "ross", "bellam"))
    o[[k]] <- tot(daily[daily$sector == k, ])
  o
}) |> setNames(names(cfg))
jsonlite::write_json(list(regions = region_labels, sources = series),
                     file.path(out, "series.json"),
                     auto_unbox = TRUE, digits = NA, na = "null")
message(sprintf("series.json written (%i regions)", length(region_labels)))

## ---------------------------------------------- per-source cell exports
## slerp-densified ring per cell (edges are great-circle arcs), as the
## sibling exporters
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
## Spilhaus via PROJ (>= 9.6); absent on older PROJ, seam cells culled
spil_of <- function(rings) tryCatch({
  s <- lapply(rings, function(r) {
    xy <- reproj::reproj_xy(r, "+proj=spilhaus", source = "EPSG:4326")
    if (!all(is.finite(xy))) return(NULL)
    if (max(sqrt(diff(xy[, 1])^2 + diff(xy[, 2])^2)) > 2e6) return(NULL)
    round(xy / 1000, 1)
  })
  if (!any(!vapply(s, is.null, TRUE))) NULL else s
}, error = function(e) { message("spilhaus unavailable: ", conditionMessage(e)); NULL })

for (src in names(cfg)) {
  p <- file.path(work, "sums", src); C <- cfg[[src]]
  d0 <- as.Date(sprintf("%i-01-01", min(C$years)))
  d1 <- as.Date(sprintf("%i-12-31", max(C$years)))
  ds <- arrow::open_dataset(p)
  percell <- ds |> filter(date >= d0, date <= d1) |>
    group_by(cell) |>
    summarise(nd = n(), sumw = sum(sumw), sumwx = sum(sumwx)) |>
    collect() |>
    mutate(mean = sumwx / sumw, w = sumw / nd)    # w: mean daily ocean km2
  ann <- ds |> filter(date >= d0, date <= d1) |>
    mutate(year = lubridate::year(date)) |>
    group_by(cell, year) |>
    summarise(sumw = sum(sumw), sumwx = sum(sumwx)) |>
    collect() |> mutate(m = sumwx / sumw)
  trend <- ann |> group_by(cell) |>
    summarise(trend = if (n() >= 0.8 * length(C$years))
      coef(lm(m ~ year))[[2]] * SCALE * TREND_PER else NA_real_, .groups = "drop")
  a0 <- max(held(p)) - 364            # computed in R, not in the arrow query
  recent <- ds |> filter(date >= a0) |>
    group_by(cell) |> summarise(sumw = sum(sumw), sumwx = sum(sumwx)) |>
    collect() |> transmute(cell, recent = sumwx / sumw)
  b0 <- as.Date(sprintf("%i-01-01", C$baseline[1]))
  b1 <- as.Date(sprintf("%i-12-31", C$baseline[2]))
  base <- ds |> filter(date >= b0, date <= b1) |>
    group_by(cell) |> summarise(sumw = sum(sumw), sumwx = sum(sumwx)) |>
    collect() |> transmute(cell, base = sumwx / sumw)
  percell <- percell |>
    left_join(trend, by = "cell") |>
    left_join(recent, by = "cell") |>
    left_join(base, by = "cell") |>
    mutate(anom = recent - base) |>
    inner_join(reg[c("cell", "lon", "lat")], by = "cell") |>
    arrange(cell)
  rings <- lapply(percell$cell, ring_of)
  spil <- spil_of(rings)
  num <- function(x, k) round(x, k)   # NA stays NA, written as null
  cells_out <- lapply(seq_len(nrow(percell)), function(i) {
    o <- list(id = percell$cell[i], ring = rings[[i]],
              mean = round(percell$mean[i] * SCALE, DIGITS),
              trend = num(percell$trend[i], 3),
              anom = num(percell$anom[i] * SCALE, DIGITS),
              w = round(percell$w[i], 1),
              lon = round(percell$lon[i], 2), lat = round(percell$lat[i], 2))
    if (!is.null(spil) && !is.null(spil[[i]])) o$sring <- spil[[i]]
    o
  })

  mon <- ds |> filter(date >= d0) |>
    mutate(ym = lubridate::year(date) * 100L + lubridate::month(date)) |>
    group_by(cell, ym) |>
    summarise(sumw = sum(sumw), sumwx = sum(sumwx)) |>
    collect() |> mutate(m = sumwx / sumw) |>
    filter(cell %in% percell$cell)
  yms <- sort(unique(mon$ym))
  mat <- matrix(NaN, nrow(percell), length(yms))
  mat[cbind(match(mon$cell, percell$cell), match(mon$ym, yms))] <- mon$m * SCALE
  con <- file(file.path(out, sprintf("monthly-%s.bin", src)), "wb")
  writeBin(as.numeric(t(mat)), con, size = 4, endian = "little")
  close(con)

  region_sets <- Map(function(lab, cc) list(label = lab, cells = which(percell$cell %in% cc) - 1L),
                     region_labels, region_cells[names(region_labels)])
  jsonlite::write_json(
    list(source = src, years = range(C$years),
         months = sprintf("%04i-%02i", yms %/% 100L, yms %% 100L),
         baseline = paste(C$baseline, collapse = "-"),
         units = list(mean = "percent", trend = "percent / decade",
                      anom = "percent", w = "km2 (mean daily ocean area)"),
         regions = region_sets, cells = cells_out),
    file.path(out, sprintf("cells-%s.json", src)),
    auto_unbox = TRUE, digits = NA, na = "null")
  message(sprintf("[%s] cells-%s.json (%i cells, %i with a trend) + monthly-%s.bin (%i months)",
                  src, src, nrow(percell), sum(!is.na(percell$trend)), src, length(yms)))
}
