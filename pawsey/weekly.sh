#!/bin/bash
## weekly refresh of the sea ice S2 record (run by pawsey/scrontab.txt):
## backfill new CDR and ASI days through their indexes, export the site
## data (site/data: the explorer, status and mechanics pages, and the cell
## trends the S2 panels are drawn from), redraw the S2 panels, push if
## anything changed.
cd "${SLURM_SUBMIT_DIR:-$PWD}"
export SLURM_SUBMIT_DIR="$PWD"
echo "trend.ice weekly: $(date -u +%FT%TZ) in $PWD"
status=0
bash pawsey/backfill-ice.sh cdr || { echo "backfill cdr FAILED" >&2; status=1; }
## ASI is the second source on the site; its failure must not stop the CDR refresh
bash pawsey/backfill-ice.sh asi || { echo "backfill asi FAILED" >&2; status=1; }
source pawsey/config.sh
$RUN Rscript pawsey/export_site.R "$WORK" site/data \
  || { echo "export FAILED" >&2; status=1; }
$RUN Rscript scripts/s2_trend_maps.R site/figures || { echo "maps FAILED" >&2; status=1; }
git add site/data site/figures/s2_trend_*.png
if git diff --cached --quiet; then echo "site unchanged"
## pull before pushing: commits made elsewhere (merges, site edits) would
## otherwise make every unattended push a rejected non-fast-forward
else git commit -q -m "site data: regenerated from sums ($(date -u +%F))" \
  && git pull -q --rebase --autostash origin main && git push -q origin main \
  && echo "site pushed" || { echo "push FAILED" >&2; status=1; }
fi
echo "trend.ice weekly: done $(date -u +%FT%TZ), status $status"
exit $status
