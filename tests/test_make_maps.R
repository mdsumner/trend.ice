## synthetic ice season COGs (22 years) + cell-year table -> make_maps.R
library(terra)
source("R/chl_on_icegrid.R")
set.seed(4)
td <- tempfile(); dir.create(td); od <- Sys.getenv("MAPS_OUT", tempfile())
tg <- ice_grid()
lat <- terra::project(xyFromCell(tg, 1:ncell(tg)), from = "EPSG:3412", to = "EPSG:4326")[, 2]
ice <- lat < -60
man <- data.frame()
for (y in 2000:2021) {
  r <- rast(tg, nlyrs = 7); names(r) <- c("advance", "retreat", "duration", "daycount", "ice_at_start", "ice_at_end", "n_missing")
  ret <- ifelse(ice, 250 + (-60 - lat) * 3 + (y - 2000) * 0.5, NA)
  adv <- ifelse(ice, 120, NA)
  values(r) <- cbind(adv, ret, ret - adv, ret - adv, 0, 0, 0)
  f <- sprintf("south_iceseason_t15_%d-02-15.tif", y)
  writeRaster(r, file.path(td, f), datatype = "INT2S", NAflag = -32768)
  man <- rbind(man, data.frame(year = y, start = sprintf("%d-02-15", y), end = sprintf("%d-02-14", y + 1),
                               threshold = 15, nobs = 365, ndropped = 0, vmin = 0, vmax = 100, status = "ok", file = f))
}
write.csv(man, file.path(td, "manifest_t15.csv"), row.names = FALSE)
cells <- which(ice)[seq(1, sum(ice), by = 7)]
cy <- expand.grid(cell = cells, ice_year = 2000:2011)
cy$rday <- 260 + round(rnorm(nrow(cy), 0, 10)); cy$timing <- "mid"
cy$peak <- -0.5 + 0.01 * (cy$rday - 260) + rnorm(nrow(cy), 0, 0.02)
cy$peak_dsr <- 25; cy$pre <- -0.7; cy$amp <- cy$peak - cy$pre
cy$mld_at <- 30; cy$temp_at <- 0; cy$salt_at <- 34; cy$mld_post <- 25; cy$temp_post <- 0; cy$salt_post <- 34
cyf <- file.path(td, "cellyears.csv.gz"); write.csv(cy, gzfile(cyf), row.names = FALSE)
out <- system2("Rscript", c("scripts/make_maps.R", td, cyf, od), stdout = TRUE, stderr = TRUE)
cat(tail(out, 4), sep = "\n")
want <- c("ice_retreat_mean.png", "ice_retreat_trend.png", "ice_duration_mean.png", "ice_duration_trend.png",
          "bloom_peak.png", "bloom_peak_dsr.png", "bloom_timing_sensitivity.png", "bran_mld_post.png",
          "s2_trend_sst.png", "s2_trend_chl.png", "s2_trend_sla.png", "s2_trend_ice.png")
stopifnot(all(file.exists(file.path(od, want))))
## slope helper: planted 0.5 day/yr -> 5 days/decade
source(textConnection(paste(readLines("scripts/make_maps.R")[grep("^row_slope", readLines("scripts/make_maps.R")):(grep("^row_slope", readLines("scripts/make_maps.R")) + 10)], collapse = "\n")))
m <- matrix(rep(1:22 * 0.5, 3), 3, byrow = TRUE); m[2, 3] <- NA
stopifnot(all(abs(row_slope(m, 2000:2021) - 0.5) < 1e-9))
cat("make_maps test pass:", od, "\n")
