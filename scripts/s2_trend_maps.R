## S2-cell trend maps for the trend.ice site, from the trend.* site exports.
##
##   Rscript scripts/s2_trend_maps.R [outdir=site/figures]
##
## Each trend.* deployment (grist sufficient statistics on S2 level-5 cells)
## publishes docs/data/cells-<source>.json with per-cell rings (lon/lat) and
## a least-squares trend of annual means. This draws them in the same south
## polar view as the ice season maps (EPSG:3412, the NSIDC 25 km extent).
##
## Sources are read from sibling clones if present (../trend.sst etc.),
## otherwise from the Pages sites. Override with environment variables
## TREND_SST, TREND_CHL, TREND_SLA (path or URL to the cells JSON). The
## sea ice panel is this repo's own export (pawsey/export_ice.R ->
## site/data/cells-cdr-sic.json, or TREND_ICE); while that file does not
## exist the panel keeps its placeholder.
##
## Writes fixed file names (the site refers to them by name):
##   s2_trend_sst.png, s2_trend_chl.png, s2_trend_sla.png, s2_trend_ice.png

suppressPackageStartupMessages({ library(jsonlite); library(sf) })

args <- commandArgs(trailingOnly = TRUE)
outdir <- path.expand(if (length(args) >= 1) args[1] else "site/figures")
dir.create(outdir, showWarnings = FALSE, recursive = TRUE)

pick <- function(env, local, url) {
  v <- Sys.getenv(env, "")
  if (nzchar(v)) return(v)
  if (file.exists(local)) return(local)
  url
}
pages <- "https://mdsumner.github.io"
src <- list(
  sst = list(file = pick("TREND_SST", "../trend.sst/docs/data/cells-oisst.json",
                         file.path(pages, "trend.sst/data/cells-oisst.json")),
             title = "SST trend (OISST)", units = "deg C / decade",
             zlim = c(-0.5, 0.5), mult = 1),
  chl = list(file = pick("TREND_CHL", "../trend.chl/docs/data/cells-occci-log10chl.json",
                         file.path(pages, "trend.chl/data/cells-occci-log10chl.json")),
             title = "Chlorophyll-a trend (OC-CCI v6.0)", units = "% / decade\n(geometric mean)",
             zlim = c(-20, 20), mult = NA),
  sla = list(file = pick("TREND_SLA", "../trend.sla/docs/data/cells-sla-cmems.json",
                         file.path(pages, "trend.sla/data/cells-sla-cmems.json")),
             title = "Sea level anomaly trend (CMEMS)", units = "mm / yr",
             zlim = c(-8, 8), mult = 1),
  ice = list(file = pick("TREND_ICE", "site/data/cells-cdr-sic.json", ""),
             title = "Sea ice concentration trend (NSIDC CDR v6)",
             units = "% conc. / decade\n(+ = more ice)",
             zlim = c(-10, 10), mult = 1))
coast_file <- pick("TREND_COAST", "../trend.sst/docs/data/coast-110m.json",
                   file.path(pages, "trend.sst/data/coast-110m.json"))

crs <- "EPSG:3412"
## the NSIDC south polar 25 km grid extent, as ice_grid() in R/chl_on_icegrid.R
xlim <- c(-3950000, 3950000); ylim <- c(-3950000, 4350000)
north <- -40   # cells with centre north of this are not drawn

proj <- function(m) sf::sf_project("EPSG:4326", crs, m, keep = TRUE, warn = FALSE)

read_cells <- function(f) {
  d <- jsonlite::fromJSON(f, simplifyVector = FALSE)
  keep <- vapply(d$cells, function(x) !is.null(x$lat) && x$lat < north, TRUE)
  list(cells = d$cells[keep], years = unlist(d$years), baseline = d$baseline)
}

coast <- local({
  cj <- jsonlite::fromJSON(coast_file, simplifyVector = FALSE)
  ## a GeoJSON MultiLineString: coordinates is a list of lines of [lon, lat]
  out <- list()
  for (x in cj$coordinates) {
    m <- do.call(rbind, lapply(x, function(p) as.numeric(unlist(p)[1:2])))
    m <- m[m[, 2] < north + 5, , drop = FALSE]
    if (nrow(m) > 1) out[[length(out) + 1]] <- proj(m)
  }
  out
})

draw <- function(key) {
  s <- src[[key]]
  d <- read_cells(s$file)
  tr <- vapply(d$cells, function(x) if (is.null(x$trend)) NA_real_ else as.numeric(x$trend), 0)
  ## chl trends are log10 units / decade: show as percent change / decade
  if (key == "chl") tr <- (10^tr - 1) * 100 else tr <- tr * s$mult
  zl <- s$zlim
  cols <- hcl.colors(101, "Blue-Red 3")
  idx <- pmin(pmax(round((tr - zl[1]) / diff(zl) * 100) + 1, 1), 101)

  f <- file.path(outdir, sprintf("s2_trend_%s.png", key))
  png(f, width = 900, height = 900, res = 110)
  on.exit(dev.off())
  layout(matrix(1:2, 1), widths = c(5, 1))
  par(mar = c(1, 1, 3, 0))
  plot(NA, xlim = xlim, ylim = ylim, asp = 1, axes = FALSE, xlab = "", ylab = "",
       main = sprintf("%s, %d-%d", s$title, d$years[1], d$years[2]))
  for (i in seq_along(d$cells)) {
    if (is.na(tr[i])) next
    r <- do.call(rbind, lapply(d$cells[[i]]$ring, function(p) as.numeric(unlist(p))))
    xy <- proj(r)
    polygon(xy[, 1], xy[, 2], col = cols[idx[i]], border = NA)
  }
  for (ln in coast) lines(ln, lwd = 0.6, col = "grey20")
  ## latitude guides
  for (lat in c(-50, -60, -70)) {
    xy <- proj(cbind(seq(-180, 180, by = 2), lat))
    lines(xy, lty = 3, col = "grey50", lwd = 0.5)
  }
  par(mar = c(6, 0.5, 6, 3.5))
  z <- seq(zl[1], zl[2], length.out = 101)
  image(1, z, matrix(z, 1), col = cols, axes = FALSE, xlab = "", ylab = "")
  axis(4, las = 1, cex.axis = 0.8)
  mtext(s$units, side = 3, line = 0.5, cex = 0.7)
  box()
  message(sprintf("%s: %d cells south of %dS, trend range %.3g..%.3g -> %s",
                  key, sum(!is.na(tr)), -north, min(tr, na.rm = TRUE), max(tr, na.rm = TRUE), f))
}

for (k in names(src)) {
  if (!nzchar(src[[k]]$file)) { message(k, ": no export yet, slot left as is"); next }
  r <- try(draw(k), silent = TRUE)
  if (inherits(r, "try-error")) message(k, ": FAILED, slot left as is: ", conditionMessage(attr(r, "condition")))
}
