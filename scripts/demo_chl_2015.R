## First look: chlorophyll against days since sea ice retreat, ice year 2015
## (retreat in spring/summer 2015-16), East and West Antarctic together.
##
##   Rscript scripts/demo_chl_2015.R [outdir=~/trend-ice-demo]
##
## Writes: map of one composite (retreat, log10 chl, days since retreat),
## the long table for the season (csv), and a binned bloom curve (png).

source("R/read_iceseason.R")
source("R/chl_on_icegrid.R")
library(terra)

args <- commandArgs(trailingOnly = TRUE)
outdir <- path.expand(if (length(args)) args[1] else "~/trend-ice-demo")
dir.create(outdir, showWarnings = FALSE, recursive = TRUE)

iceseason_acacia()   ## anonymous read; same settings serve the chl files

year <- 2015
ret <- read_iceseason("retreat", year)[[1]]

f <- chl_files(c(year, year + 1))
f <- f[f$mid >= as.Date(sprintf("%d-10-01", year)) &
       f$mid <= as.Date(sprintf("%d-03-31", year + 1)), ]
message(nrow(f), " composites ", min(f$start), " .. ", max(f$start))

## one composite as a map
pick <- f[which.min(abs(f$mid - as.Date(sprintf("%d-12-15", year)))), ]
g <- chl_on_icegrid(pick$file, template = ret)
dsr <- (as.integer(pick$mid - as.Date(sprintf("%d-02-15", year))) + 1L) - ret
names(dsr) <- "days_since_retreat"
png(file.path(outdir, sprintf("map_%s.png", format(pick$mid))), width = 1500, height = 520)
plot(c(ret, g$log10chl, dsr), nc = 3,
     main = c(sprintf("retreat (day of ice year %d)", year),
              sprintf("log10 chl, 5-day mid %s", format(pick$mid)),
              "days since retreat"))
dev.off()

## the season as a long table
tab <- do.call(rbind, lapply(seq_len(nrow(f)), function(i) {
  message(format(f$mid[i]))
  chl_dsr_table(chl_on_icegrid(f$file[i], template = ret), ret, f$mid[i], year)
}))
write.csv(tab, file.path(outdir, sprintf("chl_dsr_%d.csv", year)), row.names = FALSE)

## bloom curve: median and quartiles of log10 chl by 5-day bins of dsr
tab$bin <- 5L * (tab$dsr %/% 5L)
q <- do.call(rbind, lapply(split(tab$log10chl, tab$bin), function(v)
  c(q25 = unname(quantile(v, 0.25)), med = median(v), q75 = unname(quantile(v, 0.75)), n = length(v))))
q <- data.frame(bin = as.integer(rownames(q)), q)
write.csv(q, file.path(outdir, sprintf("bloom_curve_%d.csv", year)), row.names = FALSE)
png(file.path(outdir, sprintf("bloom_curve_%d.png", year)), width = 900, height = 600)
plot(q$bin, q$med, type = "n", ylim = range(q$q25, q$q75),
     xlab = "days since retreat", ylab = "log10 chl (mg m-3)",
     main = sprintf("Ice year %d: chlorophyll vs days since sea ice retreat", year))
polygon(c(q$bin, rev(q$bin)), c(q$q25, rev(q$q75)), col = "grey85", border = NA)
lines(q$bin, q$med, lwd = 2)
abline(v = 0, lty = 2)
dev.off()
print(q)
