# HANDOFF

Running log between sessions and machines (claude.ai cloud workspace, Nectar
VM, Setonix). Newest entry at the top. Each entry: date, where, what was done,
what is next, anything blocking. Keep entries short; detail goes in commits.

Clones: Nectar `~/Git/trend.ice`; Gadi `~/trend.ice`.

---

## 2026-11-13 (u) - timing within cell, day length: read

Retreat day varies ~12-24 d (sd) year to year at a place. Peak: earlier
than usual -> lower in Weddell / Ross (-0.07 log10 for 15+ d early);
flat elsewhere. Amplitude falls with later retreat everywhere (-0.18) but
that is largely the moving pre-retreat window (seasonal level), not
biology. Day length at retreat +0.11 with peak for early retreats.
Synthesis in `results/curves_bran/README.md`: spring retreats light- and
mixing-limited; summer retreats physically unconstrained in BRAN terms;
year-to-year variation weakly explained - iron is the likely missing piece.

Next options:

1. Fix amplitude: express the pre-retreat level against the open-water
   seasonal baseline (same latitude band, sector, date), then redo timing
2. Iron proxy: distance to shelf break / ice-shelf front / continent
3. Write-up (README methods + results, or a hypertidy.org post)

---

## 2026-11-13 (t) - within-cell retreat timing + day length

Added to `scripts/curves_bran.R` (test now uses 6 synthetic years with
cell-specific, year-varying retreat):

- `timing_withincell_correlations.csv`: per sector and all - retreat-day
  anomaly (vs the cell's own mean) against peak / amplitude anomaly, plus
  the spread of retreat-day anomalies
- `timing_withincell_bins.csv`: median peak / amp anomaly for retreats
  15+ d early, 5-15 d early, usual, 5-15 d late, 15+ d late, by sector
- `daylength_correlations.csv`: day length at the retreat date (latitude +
  date) vs peak and latitude vs peak, pooled within timing class

Next (Nectar): pull, rerun curves_bran.R, copy results, push (same commands
as (r)).

---

## 2026-11-13 (s) - BRAN controls read

Within sector, the pooled salinity signal goes away (it was between
sectors). Early retreats keep a deep-mixing penalty (Ross -0.35, B-A -0.28,
Weddell / W Pacific ~-0.16) and a fresher-is-better signal (salt -0.13 to
-0.19 in Weddell, Ross, B-A) - meltwater stratification, but only for spring
retreats. Within cell (year-to-year at a place) everything is weak
(|rho| <= 0.11). Write-up in `results/curves_bran/README.md`.

Candidate next steps (not started):

1. Within-cell test of the main driver: does an earlier / later than usual
   retreat at a place give a smaller / larger bloom there? (retreat-day
   anomaly vs peak / amp anomaly, by sector)
2. Separate light from timing: noon sun elevation or day length at the
   retreat date (deterministic from latitude + date) as a covariate
3. Place: distance to shelf break / ice shelf front (iron proxy) from
   GEBCO + coastline
4. Write-up: a short methods + results note (trend.ice README or a
   hypertidy.org post)

---

## 2026-11-13 (r) - BRAN curves v2

Rerun on Nectar after the 2026 BRAN year: 694,737 cell-years (was 1,083);
2025 now 99% matched. Summary in `results/curves_bran/README.md`: MLD after
retreat explains little pooled (only early retreat shows a deep-mixing
penalty, ~0.1 log10); the strongest pooled signal is salinity (+0.12 to
+0.18: saltier -> higher chl), probably place not process.

Added to `curves_bran.R`: correlations by sector and within cell (anomalies
from each cell's own mean over years; cells with >= 5 years). The stale
`amplitude_*` files (old outputs still in the local results dir) removed
again from the repo.

Next (Nectar):

    cd ~/Git/trend.ice && git pull
    rm -f ~/trend-ice-curves-bran/amplitude_*
    Rscript scripts/curves_bran.R ~/trend-ice-chl-v2 ~/bran_icegrid ~/trend-ice-curves-bran
    cp ~/trend-ice-curves-bran/* results/curves_bran/ && git add -A results/curves_bran && git commit -m "BRAN within-cell" && git push

---

## 2026-11-13 (q) - first BRAN join: sample artefact; reworked

First `curves_bran.R` run (Nectar): join fine (97-100% of chl rows matched
BRAN, except ice year 2025 at 29% - the BRAN tables stop at calendar 2025,
so Jan-Apr 2026 is missing). But only 1,083 cell-years qualified, and
correlations were ~0. Cause: the "clean" filter (no ice within ~75 km)
removes almost every row near retreat, and the old script took both the
state at retreat and the pre-retreat level from clean chl rows only. Not a
result - removed those outputs.

Reworked `scripts/curves_bran.R` (test updated so rows near retreat are
ice-adjacent, as in the real data):

- BRAN state comes from the BRAN tables directly, by cell and retreat date:
  `*_at` (R-5..R+5) and `*_post` (R..R+20, the stratifying window)
- bloom `peak` = max clean log10 chl over dsr 0..60 (>= 3 composites);
  `pre` from all rows (dsr -30..-1, >= 2); `amp` = peak - pre
- MLD terciles (post-retreat) within each timing tercile; outputs
  `bloom_by_timing_mld.csv`, `bloom_rank_correlations.csv`, curves

Next:

1. Gadi: `qsub -v FIRST=2026,LAST=2026 gadi/bran.sh`, then
   `DIRS="bran5day bran_icegrid" qsub gadi/publish.sh` (adds 2026)
2. Nectar: re-sync bran_icegrid, rerun curves_bran.R, push results

---

## 2026-11-13 (p) - BRAN check looks right; Acacia write probe

`check_bran.R` on 2015: 48 composites (mid 2015-01-03 .. 2015-12-29),
75,729 cells. mld median 57 m (1%-99%: 7-435 m, max 4213 - deep winter
convection / ice-shelf-front pixels, use medians), surface temp -1.8 to 10.6
(max 15.9 at the northern edge), salt 33.4-34.5 (32.1-35.1 extremes).
December map: fronts, warm north, fresh near-ice water - scale factors
applied correctly.

Added `gadi/probe_acacia.sh`: write / list / read / delete a tiny file in
`aad-derived/trend-ice/_probe/` with the pawsey1197 profile, before running
`gadi/publish.sh`.

---

## 2026-11-13 (o) - BRAN full run done; join script ready

`gadi/bran.sh` (job 183830457) ran the full range directly (no trial):
55 min walltime, 48 GB of 64 used. bran5day: 1997-2025, ~420 MB NetCDF per
year; bran_icegrid: ~72 MB parquet per year, 3,634,992 rows per year
(3,710,721 in 2024: one extra composite), i.e. ~75.7k cells x 48 Sep-Apr
composites.

Added:

- `scripts/check_bran.R`: value ranges + a Dec map of one year's table
  (sanity check, since there was no trial run)
- `scripts/curves_bran.R` (tested with a planted MLD effect,
  `tests/test_curves_bran.R`): joins chl (context run, clean, off-shelf)
  with BRAN on (cell, mid); state at retreat = mean mld/temp/salt over
  dsr -5..5; bloom amplitude = max log10 chl dsr 0..60 minus mean dsr
  -30..-1; MLD terciles within each retreat-timing tercile; amplitude
  table, Spearman correlations, curves by timing x MLD tercile.

Next:

1. Gadi: `Rscript scripts/check_bran.R` inside the container
   (`source gadi/env.sh; $RUN Rscript scripts/check_bran.R`) - expect mld
   ~5-500 m, temp ~-1.9-15, salt ~33-35; look at the png.
2. Gadi: `qsub gadi/publish.sh` (bran5day, bran_icegrid -> Acacia).
3. Nectar: `scripts/publish_acacia.sh ~/trend-ice-chl-v2 chl_dsr_v2`.
4. Nectar: cache bran_icegrid from Acacia, then
   `Rscript scripts/curves_bran.R ~/trend-ice-chl-v2 ~/bran_icegrid ~/trend-ice-curves-bran`
   and push the results to `results/curves_bran/`.

---

## 2026-11-13 (n) - BRAN remap to /g/data: clean

`gadi/remap_bran.sh` (job 183806081) into /g/data/jk72/mds581/bluelink-gdata/:

- mld: 5 ref files, 0 unmatched; checked 20 refs in 20 files, 0 problems
- temp: 380 ref files, 0 unmatched; checked 1960 refs in 273 files, 0 problems
- salt: 380 ref files, 0 unmatched; checked 1960 refs in 273 files, 0 problems

The published ausantarctic BRAN stores remap cleanly to in-situ Gadi paths -
worth a note in raad.virtualize.

Next: one-year trial of `gadi/bran.sh` (2015), then the full range.

---

## 2026-11-13 (m) - planned: VM on the Pawsey Nectar node

Plan: a VM in Nectar's Pawsey zone, close to Setonix (Slurm) and Acacia,
at the cost of slower access to the Tasmanian raad NFS. For trend.ice:

- keep machine-specific bits in thin wrappers (`gadi/` for PBS; a `pawsey/`
  set for Slurm when the VM exists); everything else reads and writes Acacia
- the one remaining raad NFS dependency is the daily ice input
  (`raadtools::readice()` in `R/ice_season.R` and `R/context.R`); putting the
  CDR daily fields on Acacia (COGs or a refs store) would make the whole
  pipeline Acacia-only
- BRAN stays on Gadi in situ (gb6), publishing results to Acacia

---

## 2026-11-13 (l) - Acacia is home

Decision: Acacia (`s3://aad-derived/trend-ice/`) is the home for everything
we create; Nectar / Gadi copies are caches. README has the layout table.

Added `scripts/publish_acacia.sh` (Nectar, AWS CLI) and `gadi/publish.sh`
(Gadi copyq, `gdal vsi sync` with AWS_PROFILE=pawsey1197 - needs
~/.aws/credentials with that profile on Gadi).

Next:

- Nectar: `scripts/publish_acacia.sh ~/trend-ice-chl-v2 chl_dsr_v2`
  (and `~/trend-ice-chl chl_dsr_v1`)
- Gadi, after `gadi/bran.sh`: `qsub gadi/publish.sh`
- the BRAN join then reads both from Acacia (anywhere)

---

## 2026-11-13 (k) - BRAN composite step written

Remap job resubmitted on Gadi (183806081).

Added (tested on synthetic data, `tests/test_bran_composites.py`,
`tests/test_bran_icegrid.py`):

- `scripts/bran_composites.py`: opens the /g/data-remapped kerchunk stores,
  averages daily mld, surface temp and surface salt (st_ocean[0]) over each
  OC-CCI 5-day composite (starts doy 1, 6, 11, ... - checked against the
  file dates), south of 48S, lon rolled to -180..180; one NetCDF per year
  with `ndays` per composite.
- `scripts/bran_to_icegrid.R`: averages each composite onto the 25 km ice
  grid; table cell, mid, mld, temp, salt for mid-dates Sep-Apr.
- `gadi/bran.sh`: runs both (normal queue, gdata/jk72+gdata/gb6), output in
  /g/data/jk72/mds581/trend-ice/{bran5day,bran_icegrid}.

Next (Gadi), after the remap job reports clean:

    git pull && qsub gadi/bran.sh

Open question: the chl tables are on Nectar, the BRAN tables will be on
Gadi. Either move the BRAN tables to Acacia (copyq) and join on Nectar, or
bring the chl tables to Gadi. Sizes: BRAN tables maybe a few GB over the
record; chl v2 tables a few hundred MB.

---

## 2026-11-13 (j) - remap fix: no pyarrow S3 needed

First `remap_bran.sh` run failed for all three: the image's pyarrow is built
without S3FileSystem. `kerchunk_remap.py` now lists source.coop with the S3
ListObjectsV2 XML API and downloads over plain https (stdlib only), with
retries for dropped connections. Tried from the cloud workspace: mld remap
OK (paths -> /g/data/gb6/BRAN/BRAN2020/daily/...), full temp scan OK (all
refs under thredds .../fileServer/gb6/, one retried file).

Next (Gadi): `git pull && qsub gadi/remap_bran.sh` (output dir is empty, so
nothing to clean up).

---

## 2026-11-13 (i) - BRAN stores: remap straight from source.coop

Container refreshed on Gadi; `gadi/check_env.sh`: everything present
(pyarrow 26, fsspec, xarray, zarr 3.4, fastparquet, kerchunk, icechunk 2.3,
terra, vapour, gdalraster, arrow; GDAL 3.13.3).

BRAN kerchunk stores (BRAN2020 daily, 12265 days from 1993-01, 0.1 deg,
1500 x 3600) on source.coop under
`ausantarctic/ausantarctic-scratch/bluelink/bluelink-daily-<var>/kerchunk`:

- `mld`: (Time, yt, xt) f4, m, chunks 1 x 661 x 1586; refs 1.7 MB
- `temp`: (Time, st_ocean[51], yt, xt) i2 scaled, chunks 1 x 1 x 300 x 300; 464 MB
- `salt`: as temp, scale 0.00168, offset 45, psu; 463 MB
- also eta_t, u, v, w, tx/ty_trans_int_z

Paths are `https://thredds.nci.org.au/thredds/fileServer/gb6/BRAN/BRAN2020/
daily/ocean_<var>_YYYY_MM.nc` -> default rule gives `/g/data/gb6/...`.

`tools/kerchunk_remap.py` now reads SRC directly from a source.coop URL (no
copy step); tried live on the mld store from the cloud workspace: 5 ref
files remapped, 0 unmatched, paths -> /g/data/gb6/BRAN/BRAN2020/daily/...

Next (Gadi):

    git pull
    qsub gadi/remap_bran.sh     # mld, temp, salt -> /g/data/jk72/mds581/bluelink-gdata/

Check the job output for "0 paths matched no rule" and "0 problems" per
variable. Then the BRAN composite step (surface temp/salt = st_ocean[0]).

---

## 2026-11-13 (h) - Gadi container setup

Gadi setup has not been used since the raad.virtualize BRAN push; the image
needs a refresh. Added `gadi/`:

- `pull.sh`: qsub job on copyq that re-pulls
  ghcr.io/hypertidy/gdal-r-python-extras into /g/data/jk72/mds581/sif_lib
  (same as the existing singul.sh)
- `env.sh`: SIF path and `singularity exec -B /g/data` wrapper
- `check_env.sh`: lists which Python modules (pyarrow, fsspec, xarray, zarr,
  fastparquet, kerchunk, icechunk, ...) and R packages (terra, vapour,
  gdalraster, arrow) the image has
- `remap.sh`: qsub job (storage gdata/jk72+gdata/gb6) running the kerchunk
  remap + check: `qsub -v SRC=...,DST=... gadi/remap.sh`

Next (Gadi):

    git clone https://github.com/mdsumner/trend.ice && cd trend.ice   # or pull
    qsub gadi/pull.sh
    ## when done:
    bash gadi/check_env.sh

Paste the check output; anything missing gets added to the image (or
pip-installed to a user site) before the remap.

---

## 2026-11-13 (g) - near-baseline result

Baseline offset was real (median 0 / 3 / 5 degrees for early / mid / late).
With baseline within 1 degree, off-shelf ordering survives and sharpens:
early ~1.2x (slow, dsr 85), mid ~1.4x (dsr 35), late ~1.8x (dsr 20) vs open
water. Late subset is small (0.14M rows) and northern. Details in
`results/curves_v2/README.md`.

---

## 2026-11-13 (f) - kerchunk remap to /g/data

Decision: run the BRAN step in situ on Gadi. Icechunk stores use absolute
https URLs and cannot be remapped in place (read-time remap needs refs
written against named `vcc://` containers); re-rendering for /g/data is
being pursued in raad.virtualize. Here: the kerchunk Parquet store.

Added `tools/kerchunk_remap.py` (destined for raad.virtualize; tested,
`tests/test_kerchunk_remap.py` - synthetic netCDF, refs pointed at THREDDS,
remapped to a local "gdata" tree, opened with xarray and compared):

- writes a NEW store; copies everything, rewrites the `path` column of each
  refs.*.parq by prefix rules (default NCI THREDDS fileServer/dodsC ->
  /g/data/); inline chunks untouched; reports paths that matched no rule
- `--scan` lists path prefixes in a store
- `--check` samples refs in the new store: file exists, byte range inside
  the file; non-zero exit on any problem or unmatched path

Next (Gadi), e.g. with the ACCESS-NRI analysis env:

    python3 tools/kerchunk_remap.py <BRAN store>.parq --scan
    python3 tools/kerchunk_remap.py <BRAN store>.parq <BRAN store>-gdata.parq --check

Open the remapped store:

    import fsspec, xarray as xr
    fs = fsspec.filesystem("reference", fo="<...>-gdata.parq", remote_protocol="file")
    ds = xr.open_dataset(fs.get_mapper(), engine="zarr",
                         backend_kwargs={"consolidated": False}, zarr_format=2)

Report back: the scan output, the check line, and `list(ds.data_vars)` with
dims, so the BRAN composite step can be written against real names.

---

## 2026-11-13 (e) - context curves reviewed

Results in `results/curves_v2/` with README. Headlines:

- Ice-edge contamination is not it: cleaning (no ice within ~75 km, 85% of
  rows kept) raises the pre-retreat level for mid/late; ice-adjacent pixels
  read lower.
- Shelf (5% of rows) carries the late-retreat high pre-retreat level
  (polynya/coastal water, ~7x open-water baseline) and the strongest blooms
  (mid-retreat shelf ~5x baseline for two months).
- Off-shelf retreat effect is modest: ~1.3x (early, slow), ~1.6x (mid,
  dsr 35), ~1.8x (late, dsr 30) vs open water - but the late figure is
  inflated by a baseline taken from further north.
- Weddell strongest off-shelf, Indian weakest.

Changed: `baseline_for()` now also returns `dlat` (latitude offset of the
baseline band); `curves_context.R` writes `timing_baseline_near` (dlat <= 1)
and `baseline_dlat_by_timing`.

Next (Nectar, quick, no rerun of data):

    git pull
    Rscript scripts/curves_context.R ~/trend-ice-chl-v2 ~/trend-ice-curves-v2
    cp ~/trend-ice-curves-v2/* results/curves_v2/
    git add results/curves_v2 && git commit -m "Context curves with near baseline" && git push

Then BRAN: MLD / SST / salinity joined on cell + composite date, starting
with off-shelf mid-retreat cells (cleanest signal).

---

## 2026-11-13 (d) - curves for the context run

Context run started on Nectar (with depth from `sds::gebco()`).

Added `R/curves.R` (bin_curve, plot_curves, retreat_timing, baseline_for)
and `scripts/curves_context.R` (tested, `tests/test_curves_context.R`):
by retreat timing as raw / clean (ice_near == 0) / clean minus open-water
baseline (same composite, sector, nearest latitude band with open water);
sector and shelf (depth > -1000 m) splits on the baseline anomaly; and a
table of pre-retreat level raw vs clean per tercile (the contamination
test).

When the run finishes (Nectar):

    git pull
    cp ~/trend-ice-chl-v2/log.csv manifests/chl_context_log.csv
    Rscript scripts/curves_context.R ~/trend-ice-chl-v2 ~/trend-ice-curves-v2
    mkdir -p results/curves_v2 && cp ~/trend-ice-curves-v2/* results/curves_v2/
    git add manifests results/curves_v2 && git commit -m "Context curves" && git push

`curves_all.R` still works on the v2 tables (extra columns are ignored).

---

## 2026-11-13 (c) - context run (baseline, ice-edge flag, depth)

Added `R/context.R` (tested, `tests/test_context.R`):

- `cell_context(template, bathy)`: cell lon/lat/sector, depth if a
  bathymetry source is given
- `ice_window(dates, template)`: percent ice over the composite's 5 days,
  max in the cell (`ice_max`) and in the 3x3 neighbourhood (`ice_near`)
- `openwater_summary()`: chl in never-iced cells (daycount 0) by 1-degree
  latitude band x sector per composite - the seasonal baseline with no
  retreat

`scripts/run_chl_context.R`: rerun of the full record into
`~/trend-ice-chl-v2/` with `ice_max`/`ice_near` on every row, an
`openwater_<year>` table per year and `cells.parquet` once. Ice for the
flags comes from raadtools::readice (5 reads per composite).

Next (Nectar):

    git pull
    nohup Rscript scripts/run_chl_context.R 1997 2025 ~/trend-ice-chl-v2 4 [BATHY] > ~/trend-ice-chl-v2.log 2>&1 &

BATHY = `sds::gebco()`, i.e.
`/vsicurl/https://data.source.coop/ausantarctic/gebco/GEBCO_2026.tif`
(no download needed: `warp_average()` uses
`vapour::gdal_raster_data()` with the ice grid's exact extent, dimension and
crs and average resampling, so GDAL reads an overview, not the full grid).

Then: curves with (a) rows with ice_near > 0 removed, (b) chl minus the
open-water baseline at the same latitude band, sector and date, (c) shelf
vs off-shelf.

---

## 2026-11-13 (b) - stratified curves reviewed

Results committed in `results/curves/` with a README summarising them.
Headline: retreat timing orders the bloom - early retreat: slow, broad, peak
~45 d, ~0.31 mg m-3; mid: sharpest and largest, peak ~25 d, ~0.40; late:
high pre-retreat level, small rise, peak ~15 d. Anomalies confirm peak
timing moving earlier with later retreat. Weddell and Ross respond most,
Indian least. Year peaks 0.23 (2024) to 0.49 (2019, 2021).

Next, to separate retreat from season and place:

1. Open-water baseline: same latitude band and dates in cells that had no
   ice season -> seasonal light cycle to subtract (or model log10chl ~
   s(day of year) + s(dsr) by sector).
2. Ice-edge contamination check: drop cells within ~50 km of the 15% edge
   on the composite date, or use chlor_a_log10_rmsd/bias, and see whether
   the late tercile's high pre-retreat level survives.
3. Shelf vs off-shelf split (GEBCO 1000 m isobath) - likely what separates
   Weddell/Ross from Indian.
4. Then BRAN covariates (MLD, SST, salinity) on cell + date.

---

## 2026-11-13 (a) - full chl run done; stratified curves script

Overnight run (Nectar, 4 cores): ice years 1997-2025 all "ok", 47-49
composites each, ~75 min total. Rows per year 183k-480k; 1997-2001 are
lowest (fewer ocean colour sensors in the merged record), 2016-2018 highest -
remember this when comparing years.

The "appending column names" warning came from the log writer; fixed.

Added `scripts/curves_all.R` (tested on synthetic tables,
`tests/test_curves_all.R`): reads all years, adds retreat day, timing
terciles (early/mid/late over all cell-years), sector (Weddell 60W-20E,
Indian 20-90E, W Pacific 90-160E, Ross 160E-130W, Bell-Amundsen 130-60W) and
a within-cell-year anomaly; writes binned curves (all, timing, sector,
sector x timing, year, anomalies) as csv + png, and peak dsr / peak median
per ice year.

Next (Nectar):

    git pull
    cp ~/trend-ice-chl/log.csv manifests/chl_dsr_log.csv
    Rscript scripts/curves_all.R ~/trend-ice-chl ~/trend-ice-curves
    git add manifests/chl_dsr_log.csv && git commit -m "chl run log" && git push

Look at timing.png and timing_anom.png first: does early retreat give a
smaller/later bloom (light-limited) and late retreat a sharper one?

---

## 2026-11-12 (n) - full chl run kicked off (overnight)

`scripts/run_chl_dsr.R`: ice years 1997-2025, composites with mid-date
Sep 1 .. Apr 30, one table per ice year (`chl_dsr_<year>.parquet`, or
.csv.gz if arrow is missing) plus `log.csv`; restartable (existing years
skipped), per-composite failures logged and skipped; `cores` workers via
mclapply.

Started on Nectar:

    nohup Rscript scripts/run_chl_dsr.R 1997 2025 ~/trend-ice-chl 4 > ~/trend-ice-chl.log 2>&1 &

Tomorrow: check `~/trend-ice-chl/log.csv` and the tail of
`~/trend-ice-chl.log`; commit `log.csv` to `manifests/chl_dsr_log.csv`; then
the stratified curves (retreat-timing terciles, shelf/off-shelf, sectors).

---

## 2026-11-12 (m) - first bloom curve (ice year 2015, Oct 2015 - Mar 2016)

36 composites, ~330k cell-composites in dsr -30..120. Median log10 chl:

- dsr -30: -0.63 (~0.23 mg m-3), flat-ish to dsr 0 (-0.50)
- rises after retreat to a peak at dsr 20-35: -0.35 (~0.45 mg m-3), about
  double the pre-retreat level
- declines steadily to -0.63 by dsr 100-120
- upper quartile peaks earlier (dsr 20: -0.05, ~0.9 mg m-3) and falls faster
- coverage: n per 5-day bin ~2-4k before retreat, ~10k at dsr 0, ~15k at
  dsr 10-50, tailing to ~6k by dsr 115

Reading: the classic ice-edge bloom, peaking 3-5 weeks after retreat.

Caveats before reading more into it:

- dsr is confounded with calendar date and latitude (early-retreat cells are
  outer pack, Oct-Nov, low light; late-retreat cells are coastal, Jan-Feb);
  different cells populate different bins
- pre-retreat (dsr < 0) values come from leads / sub-15% ice and may carry
  ice or cloud contamination

Next:

1. Stratify the curve by retreat timing (terciles of retreat day) and by
   region (shelf vs off-shelf, sectors) - this is the actual question:
   does retreat timing set bloom size and timing.
2. Per-cell anomalies (each cell against its own seasonal mean) to remove
   the composition effect.
3. All ice years 1997-2025 -> Parquet; then BRAN covariates (MLD, SST,
   salinity) joined on cell + date.

---

## 2026-11-12 (l) - demo fix

Demo failed at the 2016-02-17 composite: its mid-date falls in ice year
2016, so days were counted from Feb 15 2016 against 2015 retreat, nothing
was in range, and a zero-row data.frame errored. Fixes: `chl_dsr_table()`
takes `ice_year` and counts days from Feb 15 of that year (continuing past
day 365); zero-row result is now fine. The "[rast] CRS do not match" warning
came from mixing `ice_grid()`'s CRS with the COG's; the demo now regrids
onto the retreat raster itself (`template = ret`). Tests extended.

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
