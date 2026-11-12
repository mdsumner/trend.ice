# Context curves, ice years 1997-2025

From `scripts/curves_context.R` on the context run (`run_chl_context.R`, log
`manifests/chl_context_log.csv`). Units: median log10 chl (or log10 chl minus
the open-water baseline, i.e. log10 of the ratio to open water at the same
composite, sector and latitude band).

## 1. Ice-edge contamination: not the explanation

85% of rows have no ice within ~75 km during the composite ("clean").
Removing the rest *raises* the pre-retreat level for mid and late retreat:

| tercile | pre-retreat raw | pre-retreat clean |
|---|---|---|
| early | -0.75 | -0.77 |
| mid   | -0.63 | -0.49 |
| late  | -0.41 | -0.28 |

So ice-adjacent pixels read *lower*, not higher. The high chlorophyll before
retreat in late-retreat cells is real water, not ice contamination - it is
mostly shelf (next).

## 2. Shelf vs off-shelf (1000 m isobath), relative to open-water baseline

Shelf is only ~5% of rows but dominates the late-retreat signal:

- **shelf, late retreat**: already ~7x the open-water baseline before
  retreat (+0.83 log10), peaks at retreat, then declines - polynya / coastal
  water that is productive before the 15% retreat date at the cell.
- **shelf, mid retreat**: jumps at retreat (+0.14 -> +0.54 in a few days) to
  a sustained ~5x baseline (+0.74 at dsr 20) for two months.
- **shelf, early retreat**: slow climb to ~2.8x (+0.45) by dsr 90 - a late-
  summer shelf bloom more than a retreat response.

Off-shelf (95% of rows), the retreat effect is modest and timed:

| off-shelf tercile | pre | peak (dsr) | peak ratio to baseline |
|---|---|---|---|
| early | -0.01 | +0.10 (85) | ~1.3x, slow, seasonal |
| mid   | +0.04 | +0.19 (35) | ~1.6x |
| late  | +0.17 | +0.25 (30) | ~1.8x |

## 3. Sectors (clean, minus baseline)

Weddell strongest and earliest off-shelf (+0.25 at dsr 30); Indian weakest
(+0.07); W Pacific and Bellingshausen-Amundsen +0.17-0.23 but late (dsr
75-80); Ross +0.15 at dsr 55. Shelf: Indian, W Pacific and Ross shelf sit
5-10x above baseline throughout.

## Caveat on the baseline

Open water does not reach the latitudes of late-retreat cells, so their
baseline comes from the nearest band with open water, further north and
lower in chl. That inflates anomalies for southern (late) cells, including
the late off-shelf pre-retreat +0.17. Measured relative to its own pre-
retreat level, mid retreat has the largest off-shelf rise (+0.15) vs early
(+0.11) and late (+0.09). `curves_context.R` now also writes
`timing_baseline_near` (baseline within 1 degree only) and the median
latitude offset per tercile to quantify this.

### Near-baseline result (baseline within 1 degree of latitude)

Median latitude offset of the baseline: early 0, mid 3, late 5 degrees - the
concern was real. Restricting to rows with open water within 1 degree:

| off-shelf tercile | pre | peak (dsr) | rise | ratio | rows |
|---|---|---|---|---|---|
| early | -0.01 | +0.09 (85) | +0.09 | ~1.2x | 2.9M |
| mid   | +0.04 | +0.20 (35) | +0.15 | ~1.4x | 1.0M |
| late  | +0.10 | +0.35 (20) | +0.26 | ~1.8x | 0.14M |

The ordering survives: off-shelf, later retreat gives a larger and faster
bloom relative to open water at the same latitude, sector and date. The late
subset is the northern edge of the late-retreat cells (where open water is
near), so it is smaller and not the coastal core. Shelf rows are too few
after this restriction to say much.
