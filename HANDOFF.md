# HANDOFF

Running log between sessions and machines (claude.ai cloud workspace, Nectar
VM, Setonix). Newest entry at the top. Each entry: date, where, what was done,
what is next, anything blocking. Keep entries short; detail goes in commits.

---

## 2026-11-12 (b) - cloud workspace

Nectar report: tests pass; 2001 ran (365 obs, status ok) but the output is
all zeros (daycount 0 everywhere).

Diagnosis (likely): the raadtools ice collection now serves concentration as a
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
