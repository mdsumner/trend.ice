library(terra)
source("R/chl_on_icegrid.R")
## synthetic 4 km global chl: 0.1 everywhere south of -60, 1 between -60 and -50, NA a patch
g <- rast(ext = c(-180, 180, -90, 90), res = 1/24, crs = "EPSG:4326")
lat <- init(g, "y")
x <- ifel(lat < -60, 0.1, 1)
x[lat > -55 & init(g, "x") > 0 & init(g, "x") < 20] <- NA
x[lat < -78] <- NA   # land-ish
tf <- tempfile(fileext = ".tif"); writeRaster(x, tf)
out <- chl_on_icegrid(tf)
print(out)
v <- values(out)
print(summary(v[, "log10chl"])); print(summary(v[, "n"]))
stopifnot(all(abs(v[!is.na(v[,1]),1]) <= 0 + 1e-6 | abs(v[!is.na(v[,1]),1] + 1) < 1e-6 | (v[!is.na(v[,1]),1] > -1 & v[!is.na(v[,1]),1] < 0)))
## dates
stopifnot(ice_year_of(as.Date("2016-01-10")) == 2015, ice_year_of(as.Date("2016-02-15")) == 2016,
          ice_day_of(as.Date("2015-02-15")) == 1, ice_day_of(as.Date("2015-12-15")) == 304)
## dsr table
ret <- rast(ice_grid()); values(ret) <- 280L
tab <- chl_dsr_table(out, ret, as.Date("2015-12-15"))
print(head(tab)); stopifnot(all(tab$dsr == 24L), all(tab$n >= 1))
cat("chl tests pass\n")
