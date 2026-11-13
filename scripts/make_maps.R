## Maps for the trend.ice site (site/figures/*.png).
##
##   Rscript scripts/make_maps.R ICESRC CELLYEARS [outdir=site/figures]
##
## ICESRC     ice season COGs: a local folder (e.g. ~/iceseason_v2) or
##            "/vsis3/aad-derived/trend-ice" (Acacia, anonymous)
## CELLYEARS  cellyears.parquet (or .csv.gz) written by scripts/curves_bran.R
##
## Writes fixed file names (the site refers to them by name):
##   ice_retreat_mean.png, ice_retreat_trend.png,
##   ice_duration_mean.png, ice_duration_trend.png,
##   bloom_peak.png, bloom_peak_dsr.png, bloom_timing_sensitivity.png,
##   bran_mld_post.png
## and placeholders for maps still to come (S2-cell sufficient-statistics
## trends from the trend.* family), only if those files do not exist yet:
##   s2_trend_sst.png, s2_trend_chl.png, s2_trend_sla.png, s2_trend_ice.png

source("R/read_iceseason.R")
source("R/chl_on_icegrid.R")
suppressPackageStartupMessages(library(terra))

args <- commandArgs(trailingOnly = TRUE)
icesrc <- if (length(args) >= 1) args[1] else "/vsis3/aad-derived/trend-ice"
cyfile <- path.expand(if (length(args) >= 2) args[2] else "cellyears.parquet")
outdir <- path.expand(if (length(args) >= 3) args[3] else "site/figures")
dir.create(outdir, showWarnings = FALSE, recursive = TRUE)
if (!grepl("^/vsi", icesrc)) icesrc <- path.expand(icesrc)

template <- ice_grid()

## per-row least squares slope of y on x, NA-aware, vectorised over rows
row_slope <- function(m, x, min_n = 20) {
  ok <- !is.na(m)
  X <- matrix(x, nrow(m), ncol(m), byrow = TRUE)
  X[!ok] <- 0; Y <- m; Y[!ok] <- 0
  n <- rowSums(ok); sx <- rowSums(X); sy <- rowSums(Y)
  sxx <- rowSums(X * X); sxy <- rowSums(X * Y)
  b <- (n * sxy - sx * sy) / (n * sxx - sx^2)
  b[n < min_n] <- NA
  b
}

as_map <- function(v, name) {
  r <- rast(template, nlyrs = 1); values(r) <- v; names(r) <- name; r
}

map_png <- function(r, file, main, pal = "viridis", zlim = NULL, rev = FALSE, legend_title = "") {
  png(file.path(outdir, file), width = 900, height = 900, res = 110)
  on.exit(dev.off())
  cols <- hcl.colors(100, pal, rev = rev)
  if (is.null(zlim)) zlim <- as.numeric(global(r, range, na.rm = TRUE))
  r <- clamp(r, zlim[1], zlim[2], values = TRUE)
  par(mar = c(1, 1, 3, 1))
  plot(r, col = cols, range = zlim, axes = FALSE, main = main, mar = c(1, 1, 3, 5),
       plg = list(title = legend_title))
}

placeholder_png <- function(file, title, body) {
  f <- file.path(outdir, file)
  if (file.exists(f)) return(invisible(FALSE))
  png(f, width = 900, height = 900, res = 110)
  par(mar = c(0, 0, 0, 0))
  plot.new()
  rect(0.03, 0.03, 0.97, 0.97, border = "grey70", lty = 2)
  text(0.5, 0.62, title, cex = 1.5, font = 2)
  text(0.5, 0.45, body, cex = 1.0, col = "grey30")
  text(0.5, 0.12, sprintf("slot: figures/%s", file), cex = 0.8, col = "grey50")
  dev.off()
  invisible(TRUE)
}

## ---- ice season maps (all available ice years) ------------------------------
if (grepl("^/vsis3/", icesrc)) iceseason_acacia()
fl <- iceseason_files(NULL, 15, icesrc)
message(nrow(fl), " ice years ", min(fl$year), "-", max(fl$year))
get_var <- function(var) {
  x <- read_iceseason(var, fl$year, src = icesrc)
  values(x)
}
ret <- get_var("retreat")
dur <- get_var("duration")
yrs <- fl$year

map_png(as_map(rowMeans(ret, na.rm = TRUE), "retreat"), "ice_retreat_mean.png",
        sprintf("Mean day of sea ice retreat, %d-%d", min(yrs), max(yrs)),
        pal = "viridis", legend_title = "day of ice year\n(1 = 15 Feb)")
tr <- row_slope(ret, yrs) * 10
map_png(as_map(tr, "trend"), "ice_retreat_trend.png",
        sprintf("Trend in day of retreat, %d-%d", min(yrs), max(yrs)),
        pal = "Blue-Red 3", zlim = c(-20, 20), legend_title = "days / decade\n(+ = later)")
map_png(as_map(rowMeans(dur, na.rm = TRUE), "duration"), "ice_duration_mean.png",
        sprintf("Mean ice season duration, %d-%d", min(yrs), max(yrs)),
        pal = "Blues 3", rev = TRUE, legend_title = "days")
tr <- row_slope(dur, yrs) * 10
map_png(as_map(tr, "trend"), "ice_duration_trend.png",
        sprintf("Trend in ice season duration, %d-%d", min(yrs), max(yrs)),
        pal = "Blue-Red 3", zlim = c(-30, 30), rev = TRUE, legend_title = "days / decade\n(+ = longer)")

## ---- bloom maps from the cell-year table --------------------------------------
cy <- if (grepl("parquet$", cyfile)) as.data.frame(arrow::read_parquet(cyfile)) else utils::read.csv(cyfile)
n <- ncell(template)
med_by_cell <- function(v, min_n = 5) {
  k <- !is.na(v)
  m <- tapply(v[k], cy$cell[k], stats::median)
  cnt <- tapply(v[k], cy$cell[k], length)
  out <- rep(NA_real_, n)
  ii <- as.integer(names(m))
  out[ii] <- ifelse(cnt >= min_n, m, NA)
  out
}
yrange <- paste(range(cy$ice_year), collapse = "-")
pk <- med_by_cell(cy$peak)
map_png(as_map(10^pk, "peak"), "bloom_peak.png",
        sprintf("Median bloom peak after retreat, %s", yrange),
        pal = "YlGnBu", rev = TRUE, zlim = c(0.1, 2), legend_title = "chl-a (mg m-3)\npeak 0-60 d")
map_png(as_map(med_by_cell(cy$peak_dsr), "peak_dsr"), "bloom_peak_dsr.png",
        sprintf("Days from retreat to bloom peak (median), %s", yrange),
        pal = "Inferno", rev = TRUE, zlim = c(0, 60), legend_title = "days after\nretreat")

## year-to-year sensitivity: rank correlation of peak with retreat day, per cell
sens <- rep(NA_real_, n)
sp <- split(seq_len(nrow(cy)), cy$cell)
cnt <- vapply(sp, length, integer(1))
for (k in names(sp)[cnt >= 10]) {
  i <- sp[[k]]
  if (stats::sd(cy$rday[i]) > 0) {
    sens[as.integer(k)] <- suppressWarnings(stats::cor(cy$peak[i], cy$rday[i], method = "spearman"))
  }
}
map_png(as_map(sens, "sensitivity"), "bloom_timing_sensitivity.png",
        "Bloom peak vs retreat timing, year to year (per cell)",
        pal = "Blue-Red 3", zlim = c(-0.8, 0.8),
        legend_title = "rank corr.\n(+ = later retreat,\nbigger peak)")
map_png(as_map(med_by_cell(cy$mld_post), "mld"), "bran_mld_post.png",
        sprintf("Mixed layer depth 0-20 days after retreat (BRAN, median), %s", yrange),
        pal = "Viridis", rev = TRUE, zlim = c(5, 150), legend_title = "m")

## ---- slots for maps to come ------------------------------------------------------
placeholder_png("s2_trend_sst.png", "SST trend on S2 cells",
                "sufficient-statistics trend from trend.sst\n(grist engine) - coming")
placeholder_png("s2_trend_chl.png", "Chlorophyll trend on S2 cells",
                "sufficient-statistics trend from trend.chl\n(grist engine) - coming")
placeholder_png("s2_trend_sla.png", "Sea level anomaly trend on S2 cells",
                "sufficient-statistics trend from trend.sla\n(grist engine) - coming")
placeholder_png("s2_trend_ice.png", "Sea ice trend on S2 cells",
                "ice concentration / seasonality trend on S2 cells\n(trend.ice x grist) - coming")
message("maps written to ", outdir)
