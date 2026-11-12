## Bloom curves from the context run (run_chl_context.R).
##
##   Rscript scripts/curves_context.R [indir=~/trend-ice-chl-v2] [outdir=~/trend-ice-curves-v2]
##
## Variants, each by retreat timing tercile:
##   raw        as curves_all.R
##   clean      rows with no ice within ~75 km during the composite (ice_near == 0)
##   baseline   clean, minus the open-water median at the same composite,
##              sector and latitude band (nearest band with open water)
## and clean + baseline split by shelf (depth > -1000 m) vs off-shelf, and
## by sector. csv + png.

source("R/curves.R")
args <- commandArgs(trailingOnly = TRUE)
indir <- path.expand(if (length(args) >= 1) args[1] else "~/trend-ice-chl-v2")
outdir <- path.expand(if (length(args) >= 2) args[2] else "~/trend-ice-curves-v2")
dir.create(outdir, showWarnings = FALSE, recursive = TRUE)

read_any <- function(f) {
  if (grepl("parquet$", f)) as.data.frame(arrow::read_parquet(f)) else utils::read.csv(f)
}
read_all <- function(prefix) {
  fl <- list.files(indir, pattern = sprintf("^%s_[0-9]{4}\\.(parquet|csv\\.gz)$", prefix), full.names = TRUE)
  do.call(rbind, lapply(fl, read_any))
}
tab <- read_all("chl_dsr")
open <- read_all("openwater")
cells <- read_any(list.files(indir, pattern = "^cells\\.(parquet|csv\\.gz)$", full.names = TRUE)[1])
tab$mid <- as.Date(tab$mid); open$mid <- as.Date(open$mid)
message(nrow(tab), " rows; ", nrow(open), " open-water summaries")

ci <- match(tab$cell, cells$cell)
tab$sector <- factor(cells$sector[ci], levels = c("Weddell", "Indian", "W Pacific", "Ross", "Bell-Amundsen"))
lat_band <- floor(cells$lat[ci])
if ("depth" %in% names(cells)) {
  tab$shelf <- factor(ifelse(cells$depth[ci] > -1000, "shelf", "off-shelf"))
}
tm <- retreat_timing(tab)
tab$timing <- tm$timing
message("retreat terciles: ", paste(format(as.Date("2001-02-14") + round(tm$breaks), "%d %b"), collapse = ", "))

tab$clean <- !is.na(tab$ice_near) & tab$ice_near == 0
message(sprintf("clean rows: %.1f%%", 100 * mean(tab$clean)))
bl <- baseline_for(tab, open, lat_band)
tab$base <- bl$base
tab$dlat <- bl$dlat
tab$anom_base <- tab$log10chl - tab$base

w <- function(x, name) utils::write.csv(x, file.path(outdir, paste0(name, ".csv")), row.names = FALSE)
cl <- tab[tab$clean, ]
clb <- cl[!is.na(cl$anom_base), ]

raw <- bin_curve(tab, by = "timing"); w(raw, "timing_raw")
cln <- bin_curve(cl, by = "timing"); w(cln, "timing_clean")
bas <- bin_curve(clb, "anom_base", by = "timing"); w(bas, "timing_baseline")
plot_curves(raw, "timing", file.path(outdir, "timing_raw.png"), "By retreat timing: all rows")
plot_curves(cln, "timing", file.path(outdir, "timing_clean.png"), "By retreat timing: no ice within ~75 km")
plot_curves(bas, "timing", file.path(outdir, "timing_baseline.png"),
            "By retreat timing: clean, minus open-water baseline", "median log10 chl - baseline")

secb <- bin_curve(clb, "anom_base", by = "sector"); w(secb, "sector_baseline")
plot_curves(secb, "sector", file.path(outdir, "sector_baseline.png"),
            "By sector: clean, minus open-water baseline", "median log10 chl - baseline")

if ("shelf" %in% names(tab)) {
  sh <- bin_curve(clb[!is.na(clb$shelf), ], "anom_base", by = c("shelf", "timing")); w(sh, "shelf_timing_baseline")
  plot_curves(sh, c("shelf", "timing"), file.path(outdir, "shelf_timing_baseline.png"),
              "Shelf vs off-shelf by retreat timing: clean, minus baseline", "median log10 chl - baseline")
  shs <- bin_curve(clb[!is.na(clb$shelf), ], "anom_base", by = c("shelf", "sector")); w(shs, "shelf_sector_baseline")
}

## baseline from the row's own latitude band only (dlat <= 1): avoids
## comparing high-latitude cells with open water further north
clx <- clb[!is.na(clb$dlat) & clb$dlat <= 1, ]
message(sprintf("rows with baseline within 1 degree of latitude: %.1f%%", 100 * nrow(clx) / nrow(clb)))
basx <- bin_curve(clx, "anom_base", by = "timing"); w(basx, "timing_baseline_near")
plot_curves(basx, "timing", file.path(outdir, "timing_baseline_near.png"),
            "By retreat timing: clean, minus open-water baseline within 1 deg latitude",
            "median log10 chl - baseline")
if ("shelf" %in% names(tab)) {
  shx <- bin_curve(clx[!is.na(clx$shelf), ], "anom_base", by = c("shelf", "timing")); w(shx, "shelf_timing_baseline_near")
}
dl <- data.frame(timing = levels(clb$timing),
                 median_dlat = tapply(clb$dlat, clb$timing, stats::median, na.rm = TRUE))
w(dl, "baseline_dlat_by_timing"); print(dl)

## how much does cleaning change the pre-retreat level, per tercile
pre <- function(cv) tapply(cv$med[cv$bin < 0], cv$timing[cv$bin < 0], mean)
cmp <- data.frame(timing = levels(tab$timing), pre_raw = pre(raw), pre_clean = pre(cln))
w(cmp, "pre_retreat_raw_vs_clean"); print(cmp)
message("done: ", outdir)
