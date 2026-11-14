# trend.ice on Setonix: sea ice concentration on S2 cells

The fourth deployment of [grist](https://github.com/hypertidy/grist),
beside trend.sst, trend.sla and trend.chl: daily sea ice concentration
summed onto S2 level-5 cells, so trends and any regional series are exact
arithmetic on the sums. It feeds the "Sea ice" panel of the site's S2
trend maps.

## Source

NSIDC CDR of passive microwave sea ice concentration, G02202 v6, daily,
south, 25 km polar stereographic (316 x 332), from 1978-10-25. Read in
place through the published index (an mdim VRT over the original netCDF
files) using the grist catalog published beside it:

    https://data.source.coop/ausantarctic/ausantarctic-scratch/seaice/g02202-v6-daily-south/grist/catalog.parquet

Same product as the ice season COGs (`R/ice_season.R`), so the S2 trends
and the retreat / duration maps come from one record.

The catalog uses grist's mdim shape (`date, dsn, array, index`) and the
grid is projected, both new in grist branch `mdim-projected`. That branch
is installed into its own R library (`$MYSOFTWARE/r-lib-trend-ice`, first
on the path for these scripts only), so the other three deployments keep
the grist they were validated with.

Weights are pixel areas on the sphere (km2), so per cell `sumw` is ocean
area covered and `sumwx` is sea ice area (km2).

## Steps (from a Setonix clone at /scratch/pawsey1362/mdsumner/trend.ice)

    git clone git@github.com:mdsumner/trend.ice.git /scratch/pawsey1362/mdsumner/trend.ice
    cd /scratch/pawsey1362/mdsumner/trend.ice
    bash pawsey/check_container.sh       # login node; paste the OK/FAIL lines back
    sbatch pawsey/onboard-ice.sh         # grist branch, registry, catalog, mapping, oracle

Read the GRIST and NUMPY lines in `ice-onboard-<jobid>.out` (`n` must be
equal) and LOOK at `$WORK/oracle-2010-09-15.png` (default WORK is
`/scratch/pawsey1362/$USER/trend-ice-s2`). Only then:

    sbatch pawsey/backfill-ice.sh        # all dates; publishes to aad-derived/trend-ice/s2/
    source pawsey/config.sh
    $RUN Rscript pawsey/export_ice.R "$WORK" site/data/cells-cdr-sic.json
    $RUN Rscript scripts/s2_trend_maps.R site/figures

then commit `site/data` and `site/figures/s2_trend_*.png`. After that the
weekly scrontab entry (`pawsey/scrontab.txt`, merge with `scrontab -e`)
keeps it current and pushes (needs credentials that work without a
prompt, as for trend.sst).

## Sources

`ICE_SOURCE` in `pawsey/config.sh` (or the environment) picks the source;
work files, mapping and sums are per source, side by side.

- `cdr` (default): NSIDC CDR G02202 v6, source name `cdr-sic`, 25 km,
  `CRS=EPSG:3412` given because its index carries none.
- `asi`: Bremen ASI AMSR2 v5.4 daily south, source name `asi-sic`,
  3.125 km, from 2012-08-01, transform `percent_unit`. Onboard it the same
  way, with the source set:

      ICE_SOURCE=asi sbatch pawsey/onboard-ice.sh
      ICE_SOURCE=asi sbatch pawsey/backfill-ice.sh      # after the oracle

  The oracle prints the CRS the source netCDF itself reports; if the
  index carries none, setup stops and asks for `CRS=...`.

Both read the scratch mirrors on Acacia
(`aad-derived/raad-scratch/<host>/<path>`) by default (`MIRROR_TO`).

## Next

- An ice-days source (indicator of concentration >= 15%) needs one more
  named transform in grist; its cell means are the fraction of days with
  ice, the S2 analogue of season duration.
