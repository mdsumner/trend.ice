# trend.ice

Southern Ocean sea ice seasonality - day of advance, day of retreat, ice season
duration and day count - per pixel per ice year, as a member of the trend.*
family of ocean climate records (trend.sst, trend.sla, trend.chl).

The first purpose is a clean seasonality layer for aligning ocean colour
(chlorophyll) with the timing of sea ice retreat.

## Method

After Massom et al. (2013), applied to daily passive microwave sea ice
concentration (NSIDC 25 km, southern hemisphere, via raadtools for now).

- **Ice year**: Feb 15 to Feb 14 (365 or 366 days). Day numbers are day of the
  ice year, day 1 = Feb 15.
- **Advance**: first day of the first run of at least 5 consecutive days with
  concentration at or above the threshold (default 15%).
- **Retreat**: first day after the last day at or above the threshold, i.e.
  concentration stays below the threshold from this day to the end of the ice
  year. NA if there is ice on the last day of the ice year (no retreat), or if
  there was no advance (no ice season, e.g. isolated spurious ice days).
- **Duration**: retreat - advance.
- **Daycount**: number of days at or above the threshold.
- **Flags**: `ice_at_start`, `ice_at_end` (0/1) and `n_missing` (days with no
  value), so perennial or carry-over ice can be excluded downstream rather than
  being encoded in the values.

Observation gaps of up to `max_gap` days (default 5; covers the two-daily
early record) are linearly interpolated. A season containing a longer gap is
not computed. Dates whose field is mostly empty count as missing, not as open
water.

The input (NSIDC sea ice CDR via raadtools) has a filled daily field
throughout the SMMR years, but the SSM/I gap 1987-12-03 to 1988-01-13
(42 days) is present as empty fields, so the 1987 ice year is not computed. Other treatments exist: Stammerjohn-style
processing used a climatology for the long gap and carried the previous day
forward over two-day gaps. Seasons spanning 1987-88 should be read with that
in mind whichever treatment is used.

## Output

One Cloud Optimized GeoTIFF per ice year and threshold, native grid,
7 Int16 layers (`advance`, `retreat`, `duration`, `daycount`, `ice_at_start`,
`ice_at_end`, `n_missing`), NA = -32768:

    south_iceseason_t15_2001-02-15.tif

plus `manifest_t15.csv` (year, dates, number of observations, status).

Published to Pawsey Acacia by `scripts/publish.sh`:

    s3://aad-derived/trend-ice/iceseason_t15/   (endpoint https://projects.pawsey.org.au)

## Run

On a machine that sees the raadtools ice collection:

    Rscript R/ice_season.R 1979 2025 15 /path/to/iceseason_v2

Tests (base R only):

    Rscript tests/test_ice_season.R

## Relation to aceecostats

This replaces the sea ice season calculation in
[AustralianAntarcticDivision/aceecostats](https://github.com/AustralianAntarcticDivision/aceecostats)
(`R/calc-ice-season.R`, `inst/01-seaiceason_calculation.Rmd`). Differences:

- pixels with ice at the end of the ice year (and pixels never below the
  threshold) had retreat = 1 in the old code (`length(year_n)` where `year_n`
  was intended); here they are NA and flagged
- advance and retreat were one day early in the old code
- daycount used `> threshold` while advance/retreat used `>=`; now consistent
- long data gaps (e.g. Dec 1987 - Jan 1988) were interpolated across; now the
  season is not computed

## Status

See [HANDOFF.md](HANDOFF.md) for current state and next steps.

## Reference

Massom, R., Reid, P., Stammerjohn, S., Raymond, B., Fraser, A. and Ushio, S.
(2013). Change and variability in East Antarctic sea ice seasonality,
1979/80-2009/10. PLoS ONE 8(5): e64756.
https://doi.org/10.1371/journal.pone.0064756
