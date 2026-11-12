## Bloom curves from the full run, stratified.
##
##   Rscript scripts/curves_all.R [indir=~/trend-ice-chl] [outdir=~/trend-ice-curves]
##
## Reads chl_dsr_<year>.(parquet|csv.gz), adds per row:
##   retreat   day of the ice year of retreat (= day of mid-date - dsr)
##   timing    early / mid / late: terciles of retreat over all cell-years
##   sector    Weddell (60W-20E), Indian (20E-90E), W Pacific (90E-160E),
##             Ross (160E-130W), Bell-Amundsen (130W-60W)
##   anom      log10chl minus that cell-year's mean (shape without level)
## and writes 5-day-binned medians/quartiles for: all, by timing, by sector,
## by timing x sector, by year; csv + png.

source("R/chl_on_icegrid.R")
suppressPackageStartupMessages(library(terra))

args <- commandArgs(trailingOnly = TRUE)
indir <- path.expand(if (length(args) >= 1) args[1] else "~/trend-ice-chl")
outdir <- path.expand(if (length(args) >= 2) args[2] else "~/trend-ice-curves")
dir.create(outdir, showWarnings = FALSE, recursive = TRUE)

read_one <- function(f) {
  if (grepl("parquet$", f)) as.data.frame(arrow::read_parquet(f)) else utils::read.csv(f)
}
files <- list.files(indir, pattern = "^chl_dsr_[0-9]{4}\\.(parquet|csv\\.gz)$", full.names = TRUE)
tab <- do.call(rbind, lapply(files, read_one))
tab$mid <- as.Date(tab$mid)
message(nrow(tab), " rows, ice years ", paste(range(tab$ice_year), collapse = "-"))

## retreat day and timing terciles
day <- as.integer(tab$mid - as.Date(sprintf("%04d-02-15", tab$ice_year))) + 1L
tab$retreat <- day - tab$dsr
cy <- unique(tab[c("cell", "ice_year", "retreat")])
brk <- quantile(cy$retreat, c(1/3, 2/3))
tab$timing <- cut(tab$retreat, c(-Inf, brk, Inf), labels = c("early", "mid", "late"))
message("retreat terciles (day of ice year): ", paste(round(brk), collapse = ", "),
        " = ", paste(format(as.Date("2001-02-14") + round(brk), "%d %b"), collapse = ", "))

## sector from cell longitude
lonlat <- terra::project(terra::xyFromCell(ice_grid(), tab$cell),
                         from = "EPSG:3412", to = "EPSG:4326")
lon <- lonlat[, 1]
tab$sector <- cut((lon + 360) %% 360, c(0, 20, 90, 160, 230, 300, 360), right = FALSE,
                  labels = c("Weddell", "Indian", "W Pacific", "Ross", "Bell-Amundsen", "Weddell2"))
tab$sector[tab$sector == "Weddell2"] <- "Weddell"
tab$sector <- droplevels(tab$sector)

## anomaly within cell-year
key <- paste(tab$cell, tab$ice_year)
tab$anom <- tab$log10chl - ave(tab$log10chl, key)

tab$bin <- 5L * (tab$dsr %/% 5L)

curve <- function(d, var = "log10chl", by = NULL) {
  g <- if (is.null(by)) list(bin = d$bin) else c(list(bin = d$bin), d[by])
  f <- function(v) c(q25 = unname(quantile(v, 0.25)), med = median(v),
                     q75 = unname(quantile(v, 0.75)), n = length(v))
  a <- aggregate(d[[var]], g, f)
  out <- data.frame(a[setdiff(names(a), "x")], a$x)
  out[do.call(order, out[c(by, "bin")]), ]
}

plot_curves <- function(cv, by, file, main, ylab = "median log10 chl") {
  png(file, width = 1000, height = 650)
  grp <- interaction(cv[by], drop = TRUE)
  lv <- levels(grp)
  cols <- grDevices::hcl.colors(length(lv), "Dark 3")
  plot(cv$bin, cv$med, type = "n", xlab = "days since retreat", ylab = ylab, main = main)
  for (i in seq_along(lv)) {
    s <- cv[grp == lv[i], ]
    lines(s$bin, s$med, col = cols[i], lwd = 2)
  }
  abline(v = 0, lty = 2)
  legend("topright", lv, col = cols, lwd = 2, bty = "n", cex = 0.8)
  dev.off()
}

w <- function(x, name) utils::write.csv(x, file.path(outdir, paste0(name, ".csv")), row.names = FALSE)

all_c <- curve(tab); w(all_c, "curve_all")
tim <- curve(tab, by = "timing"); w(tim, "curve_timing")
sec <- curve(tab, by = "sector"); w(sec, "curve_sector")
tsec <- curve(tab, by = c("sector", "timing")); w(tsec, "curve_sector_timing")
yr <- curve(tab, by = "ice_year"); w(yr, "curve_year")
tim_a <- curve(tab, "anom", by = "timing"); w(tim_a, "curve_timing_anom")
sec_a <- curve(tab, "anom", by = "sector"); w(sec_a, "curve_sector_anom")

plot_curves(tim, "timing", file.path(outdir, "timing.png"), "By retreat timing (terciles)")
plot_curves(sec, "sector", file.path(outdir, "sector.png"), "By sector")
plot_curves(tim_a, "timing", file.path(outdir, "timing_anom.png"),
            "By retreat timing, anomaly within cell-year", "median anomaly (log10)")
plot_curves(sec_a, "sector", file.path(outdir, "sector_anom.png"),
            "By sector, anomaly within cell-year", "median anomaly (log10)")
for (s in levels(tab$sector)) {
  plot_curves(tsec[tsec$sector == s, ], "timing",
              file.path(outdir, sprintf("timing_%s.png", gsub("[^A-Za-z]", "", s))),
              sprintf("%s: by retreat timing", s))
}
## year summary: peak bin and peak median per ice year
pk <- do.call(rbind, lapply(split(yr, yr$ice_year), function(d) {
  d <- d[d$bin >= 0, ]; i <- which.max(d$med)
  data.frame(ice_year = d$ice_year[1], peak_dsr = d$bin[i], peak_med = d$med[i], n = sum(d$n))
}))
w(pk, "peak_by_year")
print(pk)
message("done: ", outdir)
