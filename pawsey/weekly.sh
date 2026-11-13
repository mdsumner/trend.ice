#!/bin/bash
## weekly refresh of the sea ice S2 record (run by pawsey/scrontab.txt):
## backfill new CDR days through the index, export the cell trends,
## redraw the site's S2 panels, push if anything changed.
cd "${SLURM_SUBMIT_DIR:-$PWD}"
export SLURM_SUBMIT_DIR="$PWD"
echo "trend.ice weekly: $(date -u +%FT%TZ) in $PWD"
status=0
bash pawsey/backfill-ice.sh || { echo "backfill FAILED" >&2; status=1; }
source pawsey/config.sh
$RUN Rscript pawsey/export_ice.R "$WORK" site/data/cells-cdr-sic.json \
  || { echo "export FAILED" >&2; status=1; }
$RUN Rscript scripts/s2_trend_maps.R site/figures || { echo "maps FAILED" >&2; status=1; }
git add site/data site/figures/s2_trend_*.png
if git diff --cached --quiet; then echo "site unchanged"
else git commit -q -m "S2 trends: regenerated from sums ($(date -u +%F))" && git push -q origin main \
  && echo "site pushed" || { echo "push FAILED" >&2; status=1; }
fi
echo "trend.ice weekly: done $(date -u +%FT%TZ), status $status"
exit $status
