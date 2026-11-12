## synthetic v2 tables -> curves_context.R
set.seed(2)
td <- tempfile(); dir.create(td)
cells <- data.frame(cell = 1:2000, lon = runif(2000, -180, 180), lat = runif(2000, -75, -55),
                    sector = NA, depth = ifelse(runif(2000) < 0.3, -500, -4000))
source("R/context.R")
cells$sector <- as.character(sector_of(cells$lon))
write.csv(cells, gzfile(file.path(td, "cells.csv.gz")), row.names = FALSE)
for (y in 2001:2002) {
  n <- 30000
  dsr <- sample(-30:120, n, TRUE)
  mid <- as.Date(sprintf("%d-11-01", y)) + 5 * sample(0:30, n, TRUE)
  d <- data.frame(cell = sample(cells$cell, n, TRUE), ice_year = y, mid = mid, dsr = dsr,
                  log10chl = -0.6 + 0.3 * exp(-((dsr - 25) / 20)^2) + rnorm(n, 0, 0.05), n = 30,
                  ice_max = 0, ice_near = ifelse(dsr < 0 & runif(n) < 0.5, 20, 0))
  ## contamination: iced-neighbour rows read high
  d$log10chl[d$ice_near > 0] <- d$log10chl[d$ice_near > 0] + 0.3
  write.csv(d, gzfile(file.path(td, sprintf("chl_dsr_%d.csv.gz", y))), row.names = FALSE)
  m <- unique(mid)
  o <- expand.grid(mid = m, lat_band = -60:-50, sector = c("Weddell", "Indian", "W Pacific", "Ross", "Bell-Amundsen"),
                   stringsAsFactors = FALSE)
  o$ice_year <- y; o$q25 <- -0.65; o$med <- -0.6; o$q75 <- -0.55; o$ncell <- 50L
  write.csv(o, gzfile(file.path(td, sprintf("openwater_%d.csv.gz", y))), row.names = FALSE)
}
od <- tempfile()
system2("Rscript", c("scripts/curves_context.R", td, od))
print(sort(list.files(od)))
cmp <- read.csv(file.path(od, "pre_retreat_raw_vs_clean.csv")); print(cmp)
stopifnot(all(cmp$pre_clean < cmp$pre_raw))
b <- read.csv(file.path(od, "timing_baseline.csv"))
pk <- b[b$bin == 25, "med"]; stopifnot(all(abs(pk - 0.3) < 0.05))
cat("curves_context test pass\n")
