# HANDOFF

Running log between sessions and machines (claude.ai cloud workspace, Nectar
VM, Setonix). Newest entry at the top. Each entry: date, where, what was done,
what is next, anything blocking. Keep entries short; detail goes in commits.

---

## 2026-11-12 (k) - chlorophyll onto the ice grid (first cut)

OC-CCI v6.0 5-day chl on Acacia (anonymous read):
`/vsis3/aad-derived/esacci-oc/v6.0-release/geographic/5day/chlor_a/YYYY/
ESACCI-OC-L3S-CHLOR_A-MERGED-5D_DAILY_4km_GEO_PML_OCx-YYYYMMDD-fv6.0_chlor_a.tif`
(Float32 mg m-3, NaN nodata, 8640x4320 EPSG:4326, date = composite start).

Added:

- `R/chl_on_icegrid.R`: `chl_files()`, `chl_on_icegrid()` (mean log10 chl +
  area-weighted valid count n per 25 km EPSG:3412 cell, source cropped south
  of 48S), `ice_year_of()`, `ice_day_of()`, `chl_dsr_table()` (long table:
  cell, ice_year, mid, dsr, log10chl, n; dsr -30..120, n >= 1).
- `tests/test_chl_on_icegrid.R`: synthetic regrid + date + table checks (pass).
- `scripts/demo_chl_2015.R`: ice year 2015, Oct-Mar composites: one map
  (retreat / log10 chl / dsr), the season table (csv) and a binned bloom
  curve (csv + png).
- `read_iceseason()` now reads Acacia anonymously by default (profile optional).

Next (Nectar): `git pull; Rscript scripts/demo_chl_2015.R ~/trend-ice-demo`
and look at the map and bloom curve. Expected: chl rising after dsr 0,
peaking some weeks later.

Later: whole record (1997-2025) table -> Parquet; sector split; BRAN
covariates joined on cell + date.

---

## 2026-11-12 (j) - access without VRT

Decision: no VRT/mdim index for now - that belongs with raad.virtualize and
can come later (the COGs are tiny to reprocess). Bespoke access instead:
`R/read_iceseason.R`

    source("R/read_iceseason.R")
    ret <- read_iceseason("retreat", 1997:2025)              # from Acacia
    ret <- read_iceseason("retreat", src = "~/iceseason_v2")  # local copy

returns one layer per ice year, `time()` = ice year start, names like
`retreat_2001`. Uses the manifest to skip 1987. Acacia access sets
AWS_PROFILE=pawsey1197, AWS_S3_ENDPOINT=projects.pawsey.org.au,
AWS_VIRTUAL_HOSTING=NO; the manifest is fetched with
`gdalraster::vsi_copy_file()`.

Untested against Acacia (written in the cloud workspace) - first use is the
test. vrtstack note for later: `gdal_mdim_stack()` hard-codes SourceBand 1, so
multi-band COGs need a `band` argument there (one array per band).

Next: the chlorophyll side - bring the 5-day CCI chl onto this grid.

---

## 2026-11-12 (i) - published

46 COGs (1979-2025 minus 1987) and `manifest_t15.csv` are on Acacia at
`s3://aad-derived/trend-ice/iceseason_t15/` (stale 1987 file removed first).
COGs are ~105-116 KB each.

Check still to do: confirm the full run included d5be6df (retreat only where
there is an advance) - see the one-liner in the chat log / below:

    r <- terra::rast("~/iceseason_v2/south_iceseason_t15_2001-02-15.tif")
    terra::global(!is.na(r$retreat) & is.na(r$advance), "sum")   # expect 0

Next: vrtstack index over the 46 files.

---

## 2026-11-12 (h) - publishing

Added `scripts/publish.sh`: syncs the COGs and manifest to
`s3://aad-derived/trend-ice/iceseason_t15/` with the `pawsey1197` profile
(refuses if a skipped year still has a stale file; `--delete` keeps the
bucket in step with the folder).

Next (Nectar, after the 1987 rerun is committed):

    scripts/publish.sh 15 ~/iceseason_v2

Check read access the way the other aad-derived products are read, e.g.
`gdalinfo /vsis3/aad-derived/trend-ice/iceseason_t15/south_iceseason_t15_2001-02-15.tif`
with AWS_S3_ENDPOINT / profile set, or the public https URL if the bucket
allows anonymous read. Then the vrtstack index over the 46 files.

---

## 2026-11-12 (g) - gap pinned down

Dropped dates for the 1987 ice year are exactly 1987-12-03 .. 1988-01-13
(42 days, one more than the often-quoted Dec 3 - Jan 12). Plots of the
SMMR era (Oct-Nov 1978) show a filled field every day, so the CDR fills the
every-other-day record; only the 1987-88 gap is empty. The first full run is
therefore correct except for 1987.

Change: the driver now updates rows in an existing manifest instead of
overwriting it, so a single year can be rerun.

Next (Nectar):

    git pull
    Rscript R/ice_season.R 1987 1987 15 ~/iceseason_v2
    rm ~/iceseason_v2/south_iceseason_t15_1987-02-15.tif   # stale, from the first run
    cp ~/iceseason_v2/manifest_t15.csv manifests/ && git commit -am "1987 not computed (SSM/I gap)" && git push

Then: COGs to Acacia `aad-derived/trend-ice/`, vrtstack index.

---

## 2026-11-12 (f) - 1987 check (Nectar)

`Rscript R/ice_season.R 1987 1987 15 /tmp/ice1987`: nobs 323, ndropped 42,
status "gap > max_gap, not computed". The CDR does NOT fill the 1987-88 gap:
the files exist but are empty. The first full run treated those 42 days as
open water, so its 1987 season (and possibly the SMMR years) is wrong.

Next (Nectar): rerun the full range with the current code and recommit the
manifest; check ndropped for 1979-1986 (about 180 if alternate days are
empty, 0 if the product filled them).

1987 for the chlorophyll work: irrelevant (ocean colour starts 1997). A
climatology fill (Stammerjohn-style) for 1987 can wait until someone needs
the full seasonality record.

---

## 2026-11-12 (e) - full run 1979-2025 reviewed (cloud workspace)

`manifests/manifest_t15.csv`: all 47 ice years "ok", nobs = 365/366 every
year, vmin 0 / vmax 100.

Suspicious: every year has a file for every day, including 1979-1987 (the
SMMR record is every other day) and the Dec 1987 - Jan 1988 SSM/I gap. So
the CDR as listed by raadtools has a file per day, and missing days are
either filled (interpolated in the product) or present but empty. If empty,
the old code treated them as open water - that would pull advance/retreat
into the gap.

Change: `read_ice_obs()` now drops dates whose field has less than half the
median number of valid cells (an empty or mostly empty day is a missing
observation, not open water), so `fill_daily()` interpolates short gaps and
the gap rule skips a season with a long one. Manifest gains `ndropped`;
`nobs` is now the number of dates kept.

Next (Nectar):

1. `git pull`
2. Rerun the years that should show it: `Rscript R/ice_season.R 1979 1988 15 ~/iceseason_v2`
   - expect ndropped ~ 180 per year 1979-1986 if the empty alternate days are
     present, and 1987 to come back "gap > max_gap" if the 1987-88 gap is
     empty in the files
   - if ndropped is 0 everywhere, the CDR has filled the gaps itself (check the
     product docs) and the earlier full run stands
3. If anything changed, rerun the full range and commit the manifest again.

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
