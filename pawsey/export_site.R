## pawsey/export_site.R -- the trend.ice site data, in the schema every
## trend.* site reads with the shared kit (AustralianAntarcticDivision/
## trend kit/: explorer, status, mechanics pages).
##   Rscript pawsey/export_site.R WORK [OUT=site/data]
## WORK holds s2_registry.parquet and sums/<store>/ (the Setonix work
## dir, or a local copy of aad-derived/trend-ice/s2/). A site source is
## made of one or more stores: the CDR is one BIPOLAR source from the
## south (sums/cdr-sic) and north (sums/cdr-sic-north) stores, whose
## cells are disjoint; ASI is south only. Stores that are absent are
## skipped, so the site follows whatever has been backfilled. Writes OUT:
##   status.json          per store: label, span, gaps
##   series.json          daily sea ice AREA (million km2) per region and
##                        site source (a source lists only its regions)
##   cells-<src>.json     cell rings + per-cell metrics, preset regions,
##                        month list (also read by scripts/s2_trend_maps.R)
##   monthly-<src>.bin    Float32 cell x month mean concentration (%),
##                        cell-major
## Units: the sums are concentration as a FRACTION with pixel areas (km2)
## as weights, so sumwx is sea ice area in km2. The site shows percent.
## Cell w is the cell's mean daily ocean area (km2), so for any union of
## cells sum(w * mean) is sea ice area: the explorer's "Area" series.
## (The sst/sla/chl exporters use the same w: mean sumw per time step.)
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
## site sources and their stores; full calendar years for trends,
## baselines as each source allows
cfg <- list(
  `cdr-sic` = list(stores = c("cdr-sic", "cdr-sic-north"),
                   years = 1979:2025, baseline = c(1981, 2010)),
  `asi-sic` = list(stores = "asi-sic", years = 2013:2025, baseline = c(2013, 2022)))
store_label <- c(`cdr-sic` = "CDR south", `cdr-sic-north` = "CDR north",
                 `asi-sic` = "ASI south")
sums <- function(st) file.path(work, "sums", st)
for (k in names(cfg)) cfg[[k]]$stores <- Filter(function(st) dir.exists(sums(st)), cfg[[k]]$stores)
cfg <- cfg[lengths(lapply(cfg, `[[`, "stores")) > 0]
stopifnot(length(cfg) > 0)
stores <- unique(unlist(lapply(cfg, `[[`, "stores")))
## a site source's stores as one dataset (an arrow UnionDataset)
open_src <- function(st) {
  ds <- lapply(st, function(x) arrow::open_dataset(sums(x)))
  if (length(ds) == 1) ds[[1]] else arrow::open_dataset(ds)
}
reg <- arrow::read_parquet(file.path(work, "s2_registry.parquet"))
iso <- function(d) format(as.Date(d))
held <- function(p) sort(as.Date(sub("\\.parquet$", "", list.files(p, "\\.parquet$"))))

## ---------------------------------------------------------------- regions
## every cell any store has, tagged with its hemisphere and region
store_cells <- lapply(setNames(stores, stores), function(st)
  arrow::open_dataset(sums(st)) |> distinct(cell) |> collect() |> pull(cell))
cm <- reg[reg$cell %in% unique(unlist(store_cells)), c("cell", "lon", "lat")]
cm$hemi <- ifelse(cm$lat < 0, "s", "n")
cm$region <- NA_character_
## Southern Ocean sectors as in the sea ice literature (Zwally et al.
## 1983; Parkinson & Cavalieri 2012), by cell centre longitude
S <- cm$hemi == "s"
cm$region[S] <- with(cm[S, ], ifelse(lon >= -60 & lon < 20, "weddell",
                     ifelse(lon >= 20 & lon < 90, "indian",
                     ifelse(lon >= 90 & lon < 160, "wpac",
                     ifelse(lon >= 160 | lon < -130, "ross", "bellam")))))
## Arctic and subarctic seas after the NSIDC regional masks (Meier et
## al. 2007), by cell centre: boxes in lon/lat (lon0 > lon1 wraps the
## antimeridian), first match wins, so the seas are disjoint and sum to
## the hemisphere. Boundaries are approximate at the 290 km cell grain.
## The Bering Sea is trend.sst's polygon (it follows the Aleutian arc).
box <- function(b) {
  lon <- cm$lon; lat <- cm$lat
  (if (b[1] <= b[2]) lon >= b[1] & lon < b[2] else lon >= b[1] | lon < b[2]) &
    lat >= b[3] & lat < b[4]
}
bering <- cm$cell %in% reg$cell[s2::s2_intersects(
  s2::s2_make_polygon(c(162, 170, 180, -170, -163, -157, -157, 180, 170, 162),
                      c(56, 53, 51.5, 52.5, 54.5, 57, 66, 66, 62, 60), oriented = FALSE),
  s2::s2_geog_point(reg$lon, reg$lat))]
north_rules <- list(
  central = cm$lat >= 80,
  bering = bering,
  japan = box(c(127, 142, 33, 52)),        # with the Tatar Strait
  yellow = box(c(117, 127, 34, 42)),       # Bohai and Yellow seas
  okhotsk = box(c(135, 160, 42, 63)) | box(c(160, 165, 58, 63)),   # + Penzhina Bay
  bering2 = box(c(160, 180, 55, 66)),      # coastal cells outside the polygon (Anadyr, Koryak)
  stlawrence = box(c(-71, -55, 44, 52)),   # with the Scotian shelf
  baltic = box(c(8, 31, 52, 66)),
  hudson = box(c(-98, -75, 50, 70)) | box(c(-75, -64, 59, 64.5)),  # + Foxe Basin, Hudson Strait
  caa = box(c(-125, -80, 66, 80)),
  baffin = box(c(-80, -45, 50, 80)) | box(c(-60, -40, 43, 50)),  # + Newfoundland shelf, Grand Banks
  beaufort = box(c(-156, -125, 66, 80)),
  chukchi = box(c(180, -156, 66, 80)),
  esib = box(c(143, 180, 66, 80)),
  laptev = box(c(100, 143, 66, 80)),
  kara = box(c(60, 100, 64, 80)),          # with the Ob and Yenisei estuaries
  barents = box(c(15, 60, 63, 80)),        # with the White Sea
  greenland = box(c(-45, 15, 58, 80)))     # East Greenland, Iceland, Norwegian seas
## boundaries were set so that every cell with a monthly mean of 5% or
## more at some time falls in a named sea, except Cook Inlet ("other")
N <- cm$hemi == "n"
for (k in names(north_rules)) {
  hit <- N & is.na(cm$region) & north_rules[[k]]
  cm$region[hit] <- sub("2$", "", k)
}
cm$region[N & is.na(cm$region)] <- "other"
region_cells <- c(
  list(global = cm$cell, so = cm$cell[S], so60 = cm$cell[S & cm$lat <= -60]),
  split(cm$cell, cm$region)[c("weddell", "indian", "wpac", "ross", "bellam")],
  list(nh = cm$cell[N]),
  split(cm$cell, cm$region)[c(unique(sub("2$", "", names(north_rules))), "other")])
region_labels <- list(
  global = "Global (both hemispheres)",
  so = "Southern Ocean (all cells)", so60 = "South of 60S",
  weddell = "Weddell Sea (60W-20E)", indian = "Indian Ocean (20E-90E)",
  wpac = "Western Pacific (90E-160E)", ross = "Ross Sea (160E-130W)",
  bellam = "Bellingshausen-Amundsen (130W-60W)",
  nh = "Northern Hemisphere (all cells)", central = "Central Arctic (north of 80N)",
  bering = "Bering Sea", japan = "Sea of Japan", yellow = "Bohai and Yellow seas",
  okhotsk = "Sea of Okhotsk", stlawrence = "Gulf of St. Lawrence", baltic = "Baltic Sea",
  hudson = "Hudson Bay", caa = "Canadian Arctic Archipelago",
  baffin = "Baffin Bay and Labrador Sea", beaufort = "Beaufort Sea",
  chukchi = "Chukchi Sea", esib = "East Siberian Sea", laptev = "Laptev Sea",
  kara = "Kara Sea", barents = "Barents Sea", greenland = "Greenland and Norwegian seas",
  other = "Other northern seas")
## keep regions with cells; "global" only when both hemispheres are in
region_cells <- Filter(length, region_cells)
if (!all(c("s", "n") %in% cm$hemi)) region_cells$global <- NULL
region_labels <- region_labels[names(region_cells)]
## the regions of a site source: those it has cells in (global needs both)
src_cells <- lapply(cfg, function(C) unique(unlist(store_cells[C$stores])))
src_regions <- lapply(src_cells, function(cc) {
  k <- names(region_cells)[vapply(region_cells, function(r) any(r %in% cc), TRUE)]
  if ("global" %in% k && !all(c("s", "n") %in% cm$hemi[cm$cell %in% cc])) k <- setdiff(k, "global")
  k
})
message("regions: ", paste(sprintf("%s %i", names(region_cells), lengths(region_cells)), collapse = ", "))

## ---------------------------------------------------------------- status
## per STORE (what is held where), labelled; the series are per source
status <- list(
  generated = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
  sources = lapply(stores, function(st) {
    d <- held(sums(st))
    list(label = unname(store_label[st]), first = iso(min(d)), last = iso(max(d)), n = length(d),
         gaps = as.list(iso(setdiff(seq(min(d), max(d), by = "1 day"), d))),
         provisional_days = 0L)
  }) |> setNames(stores))
jsonlite::write_json(status, file.path(out, "status.json"),
                     auto_unbox = TRUE, pretty = TRUE, na = "null")
message("status.json written")

## ---------------------------------------------------------------- series
## daily sea ice area (sum of sumwx, km2) per region, in million km2: one
## scan per store, cells tagged with hemisphere and region. A region's
## day needs every hemisphere it spans on that day (global: both).
tag <- arrow::arrow_table(data.frame(cell = cm$cell, hemi = cm$hemi, region = cm$region,
                                     s60 = cm$lat <= -60))
series <- lapply(names(cfg), function(k) {
  daily <- bind_rows(lapply(cfg[[k]]$stores, function(st)
    arrow::open_dataset(sums(st)) |>
      select(cell, date, sumwx) |>
      inner_join(tag, by = "cell") |>
      group_by(date, hemi, region, s60) |>
      summarise(a = sum(sumwx)) |>
      collect()))
  dates <- sort(unique(daily$date))
  tot <- function(d) {
    need <- length(unique(d$hemi))
    x <- d |> group_by(date) |>
      summarise(a = sum(a), nh = n_distinct(hemi), .groups = "drop") |>
      filter(nh == need)
    round(x$a[match(dates, x$date)] / 1e6, 3)
  }
  pick <- list(global = rep(TRUE, nrow(daily)), so = daily$hemi == "s",
               so60 = daily$hemi == "s" & daily$s60, nh = daily$hemi == "n")
  o <- list(dates = iso(dates))
  for (r in src_regions[[k]])
    o[[r]] <- tot(daily[if (r %in% names(pick)) pick[[r]] else daily$region %in% r, ])
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
  C <- cfg[[src]]
  d0 <- as.Date(sprintf("%i-01-01", min(C$years)))
  d1 <- as.Date(sprintf("%i-12-31", max(C$years)))
  ds <- open_src(C$stores)
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
  ## the last 12 months of each store (they may end on different days)
  recent <- bind_rows(lapply(C$stores, function(st) {
    a0 <- max(held(sums(st))) - 364   # computed in R, not in the arrow query
    arrow::open_dataset(sums(st)) |> filter(date >= a0) |>
      group_by(cell) |> summarise(sumw = sum(sumw), sumwx = sum(sumwx)) |>
      collect() |> transmute(cell, recent = sumwx / sumw)
  }))
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

  rk <- src_regions[[src]]
  region_sets <- Map(function(lab, cc) list(label = lab, cells = which(percell$cell %in% cc) - 1L),
                     region_labels[rk], region_cells[rk])
  jsonlite::write_json(
    list(source = src, stores = C$stores, years = range(C$years),
         months = sprintf("%04i-%02i", yms %/% 100L, yms %% 100L),
         baseline = paste(C$baseline, collapse = "-"),
         units = list(mean = "percent", trend = "percent / decade",
                      anom = "percent", w = "km2 (mean daily ocean area)"),
         regions = region_sets, cells = cells_out),
    file.path(out, sprintf("cells-%s.json", src)),
    auto_unbox = TRUE, digits = NA, na = "null")
  message(sprintf("[%s] cells-%s.json (%i cells, %i with a trend; stores %s) + monthly-%s.bin (%i months)",
                  src, src, nrow(percell), sum(!is.na(percell$trend)),
                  paste(C$stores, collapse = " + "), src, length(yms)))
}
