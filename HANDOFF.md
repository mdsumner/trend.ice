# HANDOFF

Running log between sessions and machines (claude.ai cloud workspace, Nectar
VM, Setonix). Newest entry at the top. Each entry: date, where, what was done,
what is next, anything blocking. Keep entries short; detail goes in commits.

---

## 2026-11-12 (d) - 2001 comparison with old rds

- CRS: old rds carries a proj4 string (Hughes ellipsoid, lat_ts -70), the CDR
  read is tagged EPSG:3412 - same grid; `set.crs(old, crs(y))` then
  `compareGeom()` is TRUE.
- retreat(new) - retreat(old): peak at +1 (12448 cells) as expected from the
  off-by-one; a long positive tail (+2: 6271, +3: 3270) - the CDR takes the
  greater of NASA Team and Bootstrap concentration, so ice reads higher and
  retreat comes later than with NASA Team alone. Algorithm, not code.
- 4253 cells were retreat = 1 in the old output (the day-1 bug: perennial or
  end-of-year ice) and are NA in the new.
- New map showed scattered retreat values in open water beyond the pack:
  isolated spurious ice days. Fix: retreat now NA where there is no advance
  (no run of 5 ice days). Test case added.

Next: `git pull`, rerun 2001 to confirm the speckle is gone, then full run.

---

## 2026-11-12 (c) - Nectar run, logged from cloud workspace

2001 reran fine: 365 obs, vmin 0 / vmax 100 after scaling, status ok.

Input product: raadtools `readice()` now reads through `read_nsidc_cdr_daily`
(NSIDC sea ice CDR), not the NASA Team `nt_*_v1.1_s.bin` files the old
aceecostats outputs used. So a comparison with the old rds will differ by
algorithm as well as by the bug fixes - judge it by the pattern (the
perennial-ice pixels and the +1 shift), not exact agreement.

Next: compare 2001 with the old rds, then full run 1979-2025 at 15 and commit
`manifest_t15.csv`. Check the CDR start date - the first ice years may come
back "no data" or "gap" if the CDR daily record starts later than 1979.

---

## 2026-11-12 (b) - cloud workspace

Nectar report: tests pass; 2001 ran (365 obs, status ok) but the output is
all zeros (daycount 0 everywhere).

Diagnosis (confirmed: raadtools terra refactor returns 0-1): concentration as a
fraction 0-1 (old outputs were from the `nt_*_v1.1_s.bin` files in percent),
so nothing reaches `>= 15`.

Change: `read_ice_obs()` scales to percent when max <= 1, with a message, and
the manifest now records `vmin`/`vmax` of the input so this is visible.

Next (Nectar):

1. Confirm the diagnosis:
   `x <- raadtools::readice("2001-08-15"); x; range(terra::values(x), na.rm = TRUE)`
2. `git pull`, rerun 2001, check the manifest `vmax` is ~100 and daycount looks
   like an ice season, then compare retreat with the old rds.

---

## 2026-11-12 - cloud workspace (claude.ai)

Done:

- Repo initialised: README (method, output layout, differences from
  aceecostats), `R/ice_season.R`, `tests/test_ice_season.R`.
- Core functions (`ice_year_dates`, `fill_daily`, `ice_season`) are base R and
  pass the synthetic tests (simple season, early/late blips, perennial ice,
  open water, land, two-daily interpolation, long-gap rule).

Not yet tested:

- `read_ice_obs()` (raadtools `icefiles()` / `readice()`) and the COG write -
  needs a machine that sees the ice collection.

Next (Nectar VM, where rdsi is visible):

1. `Rscript tests/test_ice_season.R`
2. One year first: `Rscript R/ice_season.R 2001 2001 15 ~/iceseason_v2`
   - check `icefiles(hemisphere = "south")` product/version and that the
     template grid is the NSIDC 25 km polar stereographic
3. Compare with the old output for the same year (expect retreat mostly +1,
   perennial pixels NA instead of 1):
   `.../aad.gov.au/iceseason/ice_15_retreat.rds`
4. Full run 1979-2025 at 15; commit `manifest_t15.csv` (not the COGs).
5. Report back here: product used, run time, anything odd.

Later:

- Swap `read_ice_obs()` to read through the ice index (zaro/ndr/icechunkr).
- Publish COGs to Acacia `aad-derived/trend-ice/`; vrtstack/mdim index over them.
- aceecostats: README pointer to trend.* plus an issue recording the
  `length(year_n)` retreat bug.

Open questions:

- Other thresholds (5/25/75/95 as in the old outputs) - needed now or later?
- Treatment of ice_at_start pixels with an open period (advance = 1 is
  carry-over from the previous winter) - flag only, or set NA?
