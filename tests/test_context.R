library(terra)
source("R/chl_on_icegrid.R")
source("R/context.R")
tg <- ice_grid()
## sectors
stopifnot(identical(as.character(sector_of(c(-50, 10, 50, 120, 170, -170, -100))),
                    c("Weddell", "Weddell", "Indian", "W Pacific", "Ross", "Ross", "Bell-Amundsen")))
## cell context
ctx <- cell_context(tg)
stopifnot(nrow(ctx) == ncell(tg), all(ctx$lat < -30), !anyNA(ctx$sector))
## ice window with a mock reader: one cell iced on day 3 only, fraction units
target <- cellFromXY(tg, cbind(0, 0))
reader <- function(d) {
  x <- rast(tg, nlyrs = length(d)); values(x) <- 0
  v <- values(x); v[target, 3] <- 0.6; values(x) <- v; x
}
iw <- ice_window(as.Date("2015-12-01") + 0:4, tg, reader)
v <- values(iw)
stopifnot(v[target, "ice_max"] == 60, v[target, "ice_near"] == 60)
nb <- adjacent(tg, target, directions = 8)[1, ]
stopifnot(all(v[nb, "ice_near"] == 60), all(v[nb, "ice_max"] == 0))
stopifnot(v[cellFromXY(tg, cbind(2e6, 2e6)), "ice_near"] == 0)
## open water summary
chl <- c(rast(tg), rast(tg)); names(chl) <- c("log10chl", "n")
values(chl) <- cbind(-0.5, 10)
dc <- rast(tg); values(dc) <- ifelse(ctx$lat > -60, 0L, 100L)
ow <- openwater_summary(chl, dc, ctx, as.Date("2015-12-03"), 2015)
stopifnot(all(ow$lat_band >= -60), all(ow$med == -0.5), sum(ow$ncell) == sum(ctx$lat > -60))
print(head(ow))
cat("context tests pass\n")
