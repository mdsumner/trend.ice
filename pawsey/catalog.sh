#!/bin/bash
## catalog: the grist catalog published beside the index (contract
## grist-catalog/mdim: date, dsn, array, index, source), as is. Writes
## WORK/$CAT (icefiles-<SRC>.parquet) and reports span and gaps.
set -eu
source "$(dirname "$0")/config.sh"
cd "$WORK"
curl -fsS -o "$CAT.src" "$CATALOG_URL"
## the published catalog is zstd-compressed and the container's R arrow is
## built without zstd: re-encode to snappy (pyarrow, else GDAL's Parquet
## driver), keeping the columns as they are
rm -f "$CAT"
if $RUN python3 -c "
import pyarrow.parquet as pq
t = pq.read_table('$CAT.src')
pq.write_table(t, '$CAT', compression='snappy')
print('re-encoded with pyarrow', t.num_rows, 'rows')
" 2>/dev/null; then :
elif $RUN ogr2ogr -f Parquet -lco COMPRESSION=SNAPPY "$CAT" "$CAT.src"; then
  echo "re-encoded with GDAL (ogr2ogr)"
fi
[ -s "$CAT" ] || { echo "could not re-encode the catalog (no pyarrow, no GDAL Parquet with zstd)" >&2; exit 1; }
## with a mirror, every row reads through the remapped index instead
if [ -n "$MIRROR_TO" ]; then
  [ -s "mdim-mirror-$SRC.vrt" ] || bash "$REPO/pawsey/remap_index.sh"
  $RUN python3 -c "
import pyarrow.parquet as pq, pyarrow as pa
t = pq.read_table('$CAT')
t = t.set_column(t.schema.get_field_index('dsn'), 'dsn', pa.array(['$WORK/mdim-mirror-$SRC.vrt'] * t.num_rows))
pq.write_table(t, '$CAT', compression='snappy')
print('catalog dsn ->', '$WORK/mdim-mirror-$SRC.vrt')
"
fi
$RUN Rscript - <<'R'
f <- arrow::read_parquet(Sys.getenv("CAT"))
d <- as.Date(f$date)
stopifnot(!anyNA(d), !anyDuplicated(d), all(c("dsn", "array", "index") %in% names(f)))
dd <- as.integer(diff(sort(d)))
cat(sprintf("%i dates, %s .. %s; steps: %s\n", nrow(f), min(d), max(d),
            paste(names(table(dd)), table(dd), sep = "x", collapse = " ")))
gap <- which(dd > 1)
if (length(gap)) cat("gaps after:", format(sort(d)[gap]), "\n")
R
