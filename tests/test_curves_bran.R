## synthetic chl + BRAN tables where shallow MLD at retreat gives a bigger bloom
set.seed(3)
cd <- tempfile(); bd <- tempfile(); od <- tempfile(); dir.create(cd); dir.create(bd)
ncell <- 3000
cells <- data.frame(cell = 1:ncell, lon = 0, lat = -65, sector = "Weddell", depth = -4000)
write.csv(cells, gzfile(file.path(cd, "cells.csv.gz")), row.names = FALSE)
mld_cell <- runif(ncell, 10, 100)
for (y in 2001:2002) {
  ret <- sample(250:330, ncell, TRUE)            # retreat day of ice year
  rows <- do.call(rbind, lapply(seq(-30, 90, by = 5), function(o) {
    data.frame(cell = 1:ncell, dsr = o + sample(0:4, ncell, TRUE))
  }))
  rows$mid <- as.Date(sprintf("%d-02-15", y)) - 1 + ret[rows$cell] + rows$dsr
  amp <- 0.6 * (1 - (mld_cell[rows$cell] - 10) / 90)
  rows$log10chl <- -0.7 + amp * exp(-((rows$dsr - 25) / 15)^2) * (rows$dsr >= 0) + rnorm(nrow(rows), 0, 0.03)
  rows$ice_year <- y; rows$n <- 30; rows$ice_max <- 0; rows$ice_near <- 0
  write.csv(rows, gzfile(file.path(cd, sprintf("chl_dsr_%d.csv.gz", y))), row.names = FALSE)
  for (cy in c(y, y + 1)) {
    br <- unique(rows[format(rows$mid, "%Y") == cy, c("cell", "mid")])
    br$mld <- mld_cell[br$cell]; br$temp <- 0; br$salt <- 34
    write.csv(br, gzfile(file.path(bd, sprintf("bran_icegrid_%d.csv.gz", cy))), row.names = FALSE)
  }
}
system2("Rscript", c("scripts/curves_bran.R", cd, bd, od))
s <- read.csv(file.path(od, "amplitude_by_timing_mld.csv"))
c <- read.csv(file.path(od, "amplitude_rank_correlations.csv"))
print(s); print(c)
for (tm in unique(s$timing)) {
  a <- s[s$timing == tm, ]; a <- a[match(c("shallow", "mid", "deep"), a$mld_t), ]
  stopifnot(a$amp_med[1] > a$amp_med[2], a$amp_med[2] > a$amp_med[3])
}
stopifnot(all(c$rho_mld < -0.5))
cat("curves_bran test pass\n")
