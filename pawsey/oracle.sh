#!/bin/bash
## onboarding oracle: one date, two checks (README of hypertidy/grist).
## (1) exact: the count of valid pixels (concentration in [0, 1]) summed
##     over cells must equal numpy on the same array slice, read by the
##     Python multidim API independently of grist's R path. The ice area
##     (sum of concentration x pixel area) is printed beside a cos-free
##     cross-check: numpy's unweighted sum times the mean pixel area.
## (2) look: the map. 2010-09-15, near maximum: expect ice all round the
##     continent out to ~55-60S, open water north, no flips, ice area
##     ~15-17 million km2.
##   bash pawsey/oracle.sh [date=2010-09-15]
set -eu
source "$(dirname "$0")/config.sh"
cd "$WORK"
export ORACLE_DATE=${1:-2010-09-15}
$RUN Rscript - <<'R'
library(arrow); library(grist)
reg <- read_parquet("s2_registry.parquet")
files <- read_parquet("icefiles.parquet")
d <- as.Date(Sys.getenv("ORACLE_DATE"))
i <- match(d, as.Date(files$date)); stopifnot(!is.na(i))
src <- stat_source(Sys.getenv("SRC"), files[i, ], transform = Sys.getenv("TRANSFORM"),
                   grid = list(projection = Sys.getenv("CRS")))
out <- accumulate_date(files$dsn[i], d, src, reg, out_path = "oracle-sums", overwrite = TRUE)
s <- read_parquet(out)
cat(sprintf("ORACLE %s %s %s view %s\n", d, files$array[i], files$index[i], src$files$view[1]))
cat(sprintf("GRIST n=%.0f area_km2=%.1f ice_area_Mkm2=%.3f mean_conc=%.4f\n",
            sum(s$n), sum(s$sumw), sum(s$sumwx) / 1e6, sum(s$sumwx) / sum(s$sumw)))
s$mean <- s$sumwx / s$sumw
ii <- match(s$cell, reg$cell)
png(sprintf("oracle-%s.png", d), 900, 900)
pal <- hcl.colors(101, "Blues 3", rev = TRUE)
## south polar view of the cell centres
r <- (90 + reg$lat[ii]); x <- r * sin(reg$lon[ii] * pi / 180); y <- -r * cos(reg$lon[ii] * pi / 180)
plot(x, y, col = pal[round(s$mean * 100) + 1], pch = 15, cex = 1.6, asp = 1, axes = FALSE,
     xlab = "", ylab = "", main = sprintf("%s %s: mean concentration per S2 cell (0 white, 1 dark)",
                                          Sys.getenv("SRC"), d))
text(0, 0, "S Pole"); text(0, -50, "0 E (Greenwich) ->", pos = 1)
dev.off()
writeLines(c(format(d), files$dsn[i], files$array[i], src$files$view[1]), "oracle-date.txt")
R
DSN=$(sed -n 2p oracle-date.txt); ARR=$(sed -n 3p oracle-date.txt); VIEW=$(sed -n 4p oracle-date.txt)
$RUN python3 - "$DSN" "$ARR" "$VIEW" <<'PY'
import sys, numpy as np
from osgeo import gdal
gdal.UseExceptions()
dsn, arr, view = sys.argv[1:4]
a = gdal.OpenEx(dsn, gdal.OF_MULTIDIM_RASTER).GetRootGroup().OpenMDArray(arr).GetView(view)
v = a.ReadAsArray().astype(np.float64)
nd = a.GetNoDataValueAsDouble()
if nd is not None: v[v == nd] = np.nan
sc = a.GetScale(); of = a.GetOffset()
if sc not in (None, 1): v = v * sc
if of not in (None, 0): v = v + of
ok = np.isfinite(v) & (v >= 0) & (v <= 1)
print("NUMPY n=%.0f shape=%s raw range %.3f..%.3f, valid sum=%.1f, ice px (>=0.15)=%i"
      % (ok.sum(), v.shape, np.nanmin(v), np.nanmax(v), v[ok].sum(), (v[ok] >= 0.15).sum()))
print("NUMPY approx ice area (x 625 km2, nominal pixel) Mkm2=%.3f" % (v[ok].sum() * 625 / 1e6))
PY
