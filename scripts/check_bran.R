## Quick sanity check of the BRAN ice-grid tables.
##   Rscript scripts/check_bran.R [dir=/g/data/jk72/mds581/trend-ice/bran_icegrid] [year=2015]
source("R/chl_on_icegrid.R")
suppressPackageStartupMessages(library(terra))
args <- commandArgs(trailingOnly = TRUE)
dir <- if (length(args) >= 1) args[1] else "/g/data/jk72/mds581/trend-ice/bran_icegrid"
year <- if (length(args) >= 2) as.integer(args[2]) else 2015L
d <- as.data.frame(arrow::read_parquet(file.path(dir, sprintf("bran_icegrid_%d.parquet", year))))
d$mid <- as.Date(d$mid)
cat("rows", nrow(d), " composites", length(unique(d$mid)), " cells", length(unique(d$cell)), "\n")
cat("mid range", format(range(d$mid)), "\n")
print(sapply(d[c("mld", "temp", "salt")], function(x) round(quantile(x, c(0, 0.01, 0.5, 0.99, 1), na.rm = TRUE), 2)))
## one composite in mid December as maps
m <- d$mid[which.min(abs(d$mid - as.Date(sprintf("%d-12-16", year))))]
s <- d[d$mid == m, ]
r <- rast(ice_grid(), nlyrs = 3); names(r) <- c("mld", "temp", "salt")
v <- matrix(NA_real_, ncell(r), 3); v[s$cell, ] <- as.matrix(s[c("mld", "temp", "salt")]); values(r) <- v
png(sprintf("bran_check_%s.png", format(m)), width = 1500, height = 520)
plot(r, nc = 3, main = paste(names(r), format(m)))
dev.off()
cat("map written: ", sprintf("bran_check_%s.png", format(m)), "\n")
