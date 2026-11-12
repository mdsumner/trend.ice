# Bloom curves, ice years 1997-2025 (first pass)

Produced by `scripts/curves_all.R` from the full run (`scripts/run_chl_dsr.R`,
log in `manifests/chl_dsr_log.csv`). Chlorophyll is OC-CCI v6.0 5-day, mean
log10 per 25 km ice-grid cell; days since retreat (dsr) from the 15% ice
season layer. Medians in 5-day dsr bins; ~9.8 million cell-composites.

## What they show

**Retreat timing sets bloom timing and size** (`timing.png`, `timing_anom.png`):

| retreat tercile | pre-retreat median | peak median (mg m-3) | peak dsr | shape |
|---|---|---|---|---|
| early | -0.75 (0.18) | -0.51 (0.31) | ~45 | slow rise, broad, long tail |
| mid   | -0.63 (0.23) | -0.40 (0.40) | ~25 | sharpest, largest rise |
| late  | -0.41 (0.39) | -0.41 (0.39) | ~15 | little rise above an already high level, early decline |

The within-cell-year anomalies show the same ordering with level removed: the
peak moves earlier as retreat gets later (45 -> 25 -> 15 days), and the
amplitude is largest for mid-season retreat. Consistent with light / mixing
limitation of early (spring) retreats and a short, autumn-truncated season
for late retreats.

**Sectors** (`sector.png`): Weddell and Ross have the strongest response
(peak ~0.45 mg m-3 at dsr ~30); Indian barely rises above its pre-retreat
level; W Pacific and Bellingshausen-Amundsen are intermediate.

**Years** (`peak_by_year.csv`): peak median ranges from 0.23 mg m-3 (2024) to
0.49 (2019, 2021); peak dsr 10-50 days. 2019-2022 high, 2023-2024 low.

## Caveats (not yet controlled)

- dsr and retreat timing are confounded with calendar date (light) and
  location (shelf/coast vs outer pack). The terciles differ in both.
- Late-retreat cells have high chl *before* retreat: coastal/shelf and
  polynya waters, but possibly also ice / adjacency contamination near the
  ice edge and coast.
- Coverage changes over the record (fewer sensors 1997-2001), and sensor mix
  may affect year-to-year levels; compare shapes before levels.
- Tails beyond dsr ~100 are thin for late retreats (data window ends Apr 30).
