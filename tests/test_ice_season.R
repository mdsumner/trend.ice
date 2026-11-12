source(file.path("R", "ice_season.R"))
d <- ice_year_dates(2001); stopifnot(length(d) == 365, format(d[1]) == "2001-02-15", format(d[365]) == "2002-02-14")
stopifnot(length(ice_year_dates(2004)) == 366)
nd <- 365
mk <- function(on) { v <- rep(0, nd); v[on] <- 80; v }
m <- rbind(
  a = mk(100:250),                 # simple season: adv 100, ret 251
  b = mk(c(50:52, 100:250)),       # short blip before: adv still 100
  c = mk(c(100:250, 300:302)),     # late short blip: ret 303 (persistence only on advance)
  d = mk(1:365),                   # perennial: adv 1, ret NA
  e = mk(integer(0)),              # open water: all NA except daycount 0
  f = rep(NA_real_, nd),           # land
  g = mk(c(1:30, 200:365))         # ice at start and end
)
s <- ice_season(m)
print(cbind(cell = rownames(m), s))
stopifnot(identical(s$advance, c(100L,100L,100L,1L,NA,NA,1L)),
          identical(s$retreat, c(251L,251L,303L,NA,NA,NA,NA)),
          identical(s$daycount, c(151L,154L,154L,365L,0L,NA,196L)))
## two-daily interpolation and gap rule
obs <- d[seq(1, 365, by = 2)]
mm <- m[1:2, seq(1, 365, by = 2)]
f <- fill_daily(mm, obs, d); stopifnot(ncol(f) == 365)
stopifnot(is.null(fill_daily(mm[, -(50:60)], obs[-(50:60)], d)))
cat("all tests pass\n")
