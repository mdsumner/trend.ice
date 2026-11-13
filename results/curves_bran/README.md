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

## Controls: by sector and within cell

**Within sector** (`bloom_rank_correlations_by_sector.csv`) the pooled
salinity signal goes away (mostly -0.07..+0.08); it was a between-sector
contrast. What remains is for **early** retreat: deeper mixing goes with a
lower peak, strongest in the Ross (-0.35) and Bellingshausen-Amundsen
(-0.28) sectors, weaker in Weddell / W Pacific (-0.16, -0.17), ~0 in the
Indian sector; and fresher water goes with a higher peak there (salt -0.13
to -0.19 in Weddell, Ross, B-A). That is the meltwater-stratification
picture, but only for spring retreats, when mixed layers are still deep.
Mid and late retreats: all |rho| < 0.16.

**Within cell** (`bloom_withincell_correlations.csv`, year-to-year at a
place, ~20-25k cells each): everything is weak, |rho| <= 0.11. Largest:
amplitude vs post-retreat temperature -0.06 to -0.11 (warmer than usual,
smaller rise), amplitude vs MLD +0.06 to +0.11, late-retreat peak vs
temperature +0.09.

Reading: BRAN's post-retreat state explains spatial differences for early
retreats (where in a sector the water mixes deeply and stays salty) but
very little of year-to-year bloom variation at a given place. Retreat
timing and shelf/place explain far more. Caveats: BRAN is a reanalysis with
few observations under or near the ice; 5-day / 25 km averaging; the bloom
metric is noisy; light and iron are not in BRAN.

## Retreat timing year to year, and day length

`timing_withincell_correlations.csv`, `timing_withincell_bins.csv`,
`daylength_correlations.csv`. Retreat day varies by ~12-24 days (sd) from
year to year at a place (Indian least, Bellingshausen-Amundsen most).

**Peak** (the clean metric): an earlier-than-usual retreat gives a lower
peak in the Weddell and Ross (15+ days early: -0.07 log10, ~15% lower;
later than usual: up to +0.04 in the Ross). Indian, W Pacific: flat.
Bellingshausen-Amundsen: both extremes lower. Overall within-cell rho
+0.01 - a sector-specific effect, not a universal one.

**Amplitude** (peak minus pre-retreat level) falls with later retreat in
every sector (rho -0.08 to -0.37, all -0.18). Treat with care: the
pre-retreat window moves with the retreat date, so a late retreat compares
the peak against a mid-summer (already higher) level and an early retreat
against a spring (low) level. Much of this is that seasonal shift, not
biology. A fair amplitude needs the pre-retreat level expressed against
the seasonal cycle (e.g. the open-water baseline at that latitude and date).

**Day length** at retreat (latitude + date): for early retreats, more light
at retreat goes with a higher peak (rho +0.11; latitude alone -0.07); for
mid and late retreats ~0.04.

## Overall picture so far

Spring (early) retreats are light- and mixing-limited: deeper post-retreat
mixed layers (Ross -0.35, B-A -0.28), shorter days and earlier-than-usual
retreat (Weddell, Ross) all lower the bloom peak, and fresher surface water
helps. Summer (mid / late) retreats sit in shallow, stratified water with
long days; physical state then explains little, and place (shelf, sector)
and timing class dominate. Year-to-year variation at a place is only
weakly explained by any of these - the missing driver is probably iron
supply, which BRAN does not carry.
