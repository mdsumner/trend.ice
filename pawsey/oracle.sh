#!/bin/bash
## onboarding oracle: one date, checks as in the README of hypertidy/grist.
## (1) exact: the count of valid pixels summed over cells must equal numpy
##     on the same array slice, read by the Python multidim API
##     independently of grist's R path (same transform rule).
## (2) look: the map. Mid-September is near maximum: ice all round the
##     continent out to ~55-60S, open water north, no flips.
## (3) cross-checks: the CRS the source netCDF itself reports (for a
##     source whose index carries none), and for a second source, the CDR
##     sums for the same day when they exist (ice area should be close;
##     ASI and the CDR differ by algorithm, typically by several percent).
##   bash pawsey/oracle.sh [date]            (ICE_SOURCE=cdr|asi)
set -eu
source "$(dirname "$0")/config.sh"
cd "$WORK"
export ORACLE_DATE=${1:-$ORACLE_DEFAULT}
$RUN Rscript - <<'R'
library(arrow); library(grist)
reg <- read_parquet("s2_registry.parquet")
files <- read_parquet(Sys.getenv("CAT"))
d <- as.Date(Sys.getenv("ORACLE_DATE"))
i <- match(d, as.Date(files$date)); stopifnot(!is.na(i))
src <- stat_source(Sys.getenv("SRC"), files[i, ], transform = Sys.getenv("TRANSFORM"),
                   grid = if (nzchar(Sys.getenv("CRS"))) list(projection = Sys.getenv("CRS")) else NULL)
cat(sprintf("GRID dim %s; projected %s; flip_y %s\n", paste(src$grid$dimension, collapse = " x "),
            src$grid$projected, isTRUE(src$grid$flip_y)))
out <- accumulate_date(files$dsn[i], d, src, reg, out_path = "oracle-sums", overwrite = TRUE)
s <- read_parquet(out)
cat(sprintf("ORACLE %s %s %s %s view %s\n", Sys.getenv("SRC"), d, files$array[i], files$index[i], src$files$view[1]))
cat(sprintf("GRIST n=%.0f area_km2=%.1f ice_area_Mkm2=%.3f mean_conc=%.4f\n",
            sum(s$n), sum(s$sumw), sum(s$sumwx) / 1e6, sum(s$sumwx) / sum(s$sumw)))
cdr <- file.path("sums", "cdr-sic", sprintf("%s.parquet", d))
if (Sys.getenv("SRC") != "cdr-sic" && file.exists(cdr)) {
  k <- read_parquet(cdr)
  cat(sprintf("CDR same day: ice_area_Mkm2=%.3f (n=%.0f, 25 km)\n", sum(k$sumwx) / 1e6, sum(k$n)))
}
s$mean <- s$sumwx / s$sumw
ii <- match(s$cell, reg$cell)
png(sprintf("oracle-%s-%s.png", Sys.getenv("SRC"), d), 900, 900)
pal <- hcl.colors(101, "Blues 3", rev = TRUE)
## south polar view of the cell centres, Greenwich down, 90E right
r <- (90 + reg$lat[ii]); x <- r * sin(reg$lon[ii] * pi / 180); y <- -r * cos(reg$lon[ii] * pi / 180)
plot(x, y, col = pal[round(pmin(1, pmax(0, s$mean)) * 100) + 1], pch = 15, cex = 1.6, asp = 1, axes = FALSE,
     xlab = "", ylab = "", main = sprintf("%s %s: mean concentration per S2 cell (0 white, 1 dark)",
                                          Sys.getenv("SRC"), d))
text(0, 0, "S Pole"); text(0, -50, "0 E (Greenwich) ->", pos = 1)
dev.off()
writeLines(c(format(d), files$dsn[i], files$array[i], src$files$view[1], if (is.null(files$source)) "" else files$source[i]),
           "oracle-date.txt")
R
DSN=$(sed -n 2p oracle-date.txt); ARR=$(sed -n 3p oracle-date.txt); VIEW=$(sed -n 4p oracle-date.txt)
SRCFILE=$(sed -n 5p oracle-date.txt)
$RUN python3 - "$DSN" "$ARR" "$VIEW" "$TRANSFORM" <<'PY'
import sys, numpy as np
from osgeo import gdal
gdal.UseExceptions()
dsn, arr, view, tf = sys.argv[1:5]
a = gdal.OpenEx(dsn, gdal.OF_MULTIDIM_RASTER).GetRootGroup().OpenMDArray(arr).GetView(view)
v = a.ReadAsArray().astype(np.float64)
nd = a.GetNoDataValueAsDouble()
if nd is not None: v[v == nd] = np.nan
sc = a.GetScale(); of = a.GetOffset()
if sc not in (None, 1): v = v * sc
if of not in (None, 0): v = v + of
print("NUMPY raw range %.3f..%.3f shape=%s" % (np.nanmin(v), np.nanmax(v), v.shape))
if tf == "percent_unit":
    ok = np.isfinite(v) & (v >= 0) & (v <= 100); x = v / 100
else:
    ok = np.isfinite(v) & (v >= 0) & (v <= 1); x = v
print("NUMPY n=%.0f valid sum=%.1f, ice px (>=0.15)=%i" % (ok.sum(), x[ok].sum(), (x[ok] >= 0.15).sum()))
PY
## the CRS the source file reports by itself (classic open of the array)
if [ -n "$SRCFILE" ]; then
  F=${SRCFILE}
  if [ -n "${MIRROR_TO:-}" ]; then F=$(echo "$F" | sed "s#$MIRROR_FROM#$MIRROR_TO#"); fi
  echo "source file: $F"
  $RUN gdalsrsinfo -o proj4 "NETCDF:\"$F\":$ARR" 2>/dev/null | sed 's/^/source file CRS: /' \
    || echo "source file CRS: (none reported)"
fi
rm -rf oracle-sums
