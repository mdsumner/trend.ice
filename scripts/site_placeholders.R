## Write "pending" placeholder PNGs for any site map that does not exist yet,
## so the site builds before scripts/make_maps.R has been run.
##   Rscript scripts/site_placeholders.R [outdir=site/figures]
args <- commandArgs(trailingOnly = TRUE)
outdir <- if (length(args)) args[1] else "site/figures"
dir.create(outdir, showWarnings = FALSE, recursive = TRUE)
maps <- c(ice_retreat_mean = "Mean day of retreat", ice_retreat_trend = "Trend in day of retreat",
          ice_duration_mean = "Mean ice season duration", ice_duration_trend = "Trend in ice season duration",
          bloom_peak = "Median bloom peak", bloom_peak_dsr = "Days from retreat to peak",
          bloom_timing_sensitivity = "Peak vs retreat timing, year to year",
          bran_mld_post = "Mixed layer depth after retreat",
          s2_trend_sst = "SST trend on S2 cells", s2_trend_chl = "Chlorophyll trend on S2 cells",
          s2_trend_sla = "Sea level anomaly trend on S2 cells", s2_trend_ice = "Sea ice trend on S2 cells")
for (nm in names(maps)) {
  f <- file.path(outdir, paste0(nm, ".png"))
  if (file.exists(f)) next
  coming <- grepl("^s2_", nm)
  png(f, width = 900, height = 900, res = 110)
  par(mar = c(0, 0, 0, 0)); plot.new()
  rect(0.03, 0.03, 0.97, 0.97, border = "grey70", lty = 2)
  text(0.5, 0.62, maps[[nm]], cex = 1.5, font = 2)
  text(0.5, 0.45, if (coming) "S2-cell sufficient-statistics trend\n(trend.* family) - coming"
                  else "map pending: scripts/make_maps.R", cex = 1.0, col = "grey30")
  text(0.5, 0.12, sprintf("slot: figures/%s.png", nm), cex = 0.8, col = "grey50")
  dev.off()
}
