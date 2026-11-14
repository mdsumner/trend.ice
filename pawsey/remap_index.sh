#!/bin/bash
## Remap the published CDR index (mdim VRT) to a mirror: same index, its
## source references point at a copy of the NSIDC files instead of NSIDC.
## Writes WORK/mdim-mirror-<SRC>.vrt and reports how many sources were remapped
## and whether a sample of them exist. The published index is not touched.
##   bash pawsey/remap_index.sh            (MIRROR_FROM / MIRROR_TO in config.sh)
set -eu
source "$(dirname "$0")/config.sh"
cd "$WORK"
[ -n "$MIRROR_TO" ] || { echo "MIRROR_TO not set (pawsey/config.sh)" >&2; exit 1; }
curl -fsS -o mdim-published-$SRC.vrt "$INDEX_URL"
n_from=$(grep -o "$MIRROR_FROM" mdim-published-$SRC.vrt | wc -l)
sed "s#$MIRROR_FROM#$MIRROR_TO#g" mdim-published-$SRC.vrt > mdim-mirror-$SRC.vrt.tmp
n_to=$(grep -o "$MIRROR_TO" mdim-mirror-$SRC.vrt.tmp | wc -l)
## MIRROR_TO usually starts with MIRROR_FROM (both /vsicurl/https://), so
## "left" = references with the source prefix that are not the mirror's
n_left=$(( $(grep -o "$MIRROR_FROM" mdim-mirror-$SRC.vrt.tmp | wc -l) - n_to ))
echo "references to source prefix: $n_from; remapped: $n_to; left on source: $n_left"
## sample 20 remapped files and check they exist on the mirror (HEAD)
miss=0
for f in $(grep -o "$MIRROR_TO[^<\"]*\.nc" mdim-mirror-$SRC.vrt.tmp | sort -u | shuf -n 20 --random-source=<(yes)); do
  url=${f#/vsicurl/}
  curl -fsSI -o /dev/null "$url" || { echo "MISSING on mirror: $url"; miss=$((miss + 1)); }
done
echo "sample of 20 mirror files: $((20 - miss)) present"
[ "$miss" -eq 0 ] || { echo "mirror incomplete: not switching" >&2; rm -f mdim-mirror-$SRC.vrt.tmp; exit 1; }
mv mdim-mirror-$SRC.vrt.tmp mdim-mirror-$SRC.vrt
echo "wrote $WORK/mdim-mirror-$SRC.vrt"
