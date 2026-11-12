#!/usr/bin/env bash
## Publish the ice season COGs and manifest to Pawsey Acacia.
##
## usage: scripts/publish.sh [threshold=15] [srcdir=~/iceseason_v2]
## needs the AWS CLI with the [pawsey1197] profile configured.
set -euo pipefail

THR=$(printf "%02d" "${1:-15}")
SRC="${2:-$HOME/iceseason_v2}"
ENDPOINT="https://projects.pawsey.org.au"
DEST="s3://aad-derived/trend-ice/iceseason_t${THR}/"

## a skipped year writes no file; make sure no stale file is left for it
if grep -q "not computed" "$SRC/manifest_t${THR}.csv"; then
  for y in $(awk -F, 'NR > 1 && /not computed/ {print $1}' "$SRC/manifest_t${THR}.csv"); do
    f="$SRC/south_iceseason_t${THR}_${y}-02-15.tif"
    if [ -e "$f" ]; then echo "stale file for skipped year: $f (remove it first)"; exit 1; fi
  done
fi

aws --profile pawsey1197 --endpoint-url "$ENDPOINT" s3 sync "$SRC/" "$DEST" \
  --exclude "*" --include "south_iceseason_t${THR}_*.tif" --include "manifest_t${THR}.csv" \
  --delete

aws --profile pawsey1197 --endpoint-url "$ENDPOINT" s3 ls "$DEST" | tail -5
