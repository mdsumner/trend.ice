# Bloom vs BRAN physical state after retreat (first pass)

From `scripts/curves_bran.R`: off-shelf cells, 1997-2025; 694,737 cell-years
with a clean bloom peak (max log10 chl, dsr 0..60) and BRAN after retreat
(mean over 0-20 days after retreat); 154,409 also with a pre-retreat level.
MLD terciles are within each retreat-timing tercile.

| timing | MLD tercile | MLD after retreat (m) | temp | salt | peak median (log10) | amp median |
|---|---|---|---|---|---|---|
| early | shallow | 39  | -0.65 | 33.97 | -0.33 | 0.32 |
| early | mid     | 65  | -0.86 | 33.99 | -0.33 | 0.37 |
| early | deep    | 116 | -0.65 | 34.10 | -0.43 | 0.35 |
| mid   | shallow | 15  |  0.05 | 33.95 | -0.28 | 0.36 |
| mid   | mid     | 25  | -0.30 | 33.97 | -0.28 | 0.30 |
| mid   | deep    | 43  | -0.46 | 34.00 | -0.25 | 0.33 |
| late  | shallow | 14  |  0.05 | 33.93 | -0.30 | 0.23 |
| late  | mid     | 21  | -0.23 | 33.95 | -0.25 | 0.23 |
| late  | deep    | 33  | -0.43 | 33.97 | -0.24 | 0.21 |

Pooled Spearman correlations are weak: peak vs MLD -0.12 (early), +0.04
(mid), +0.06 (late); amplitude vs MLD ~0. The strongest pooled signal is
salinity: peak +0.18 (mid) / +0.12 (late), amplitude +0.18 / +0.15 -
saltier (less meltwater-freshened) surface water after retreat goes with
higher chlorophyll. That runs against "meltwater stratification makes the
bloom" and is likely place (water mass, sector, distance from the ice
edge) rather than process.

Only early retreat shows the expected deep-mixing penalty (deep tercile
peak 0.1 log10 lower, ~20%). Mid and late retreats already sit in shallow
summer mixed layers (median 15-43 m), so MLD varies little and does not
limit the bloom there.

Pooled numbers mix place with process. The script now also writes
correlations by sector and **within cell** (each cell-year minus that
cell's mean over years: does a shallower / fresher / warmer than usual
state at a place go with a bigger than usual bloom there?). Those are the
numbers to read next.
