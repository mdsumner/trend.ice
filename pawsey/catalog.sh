#!/bin/bash
## catalog: the grist catalog published beside the index (contract
## grist-catalog/mdim: date, dsn, array, index, source), as is. Writes
## WORK/icefiles.parquet and reports span and gaps.
set -eu
source "$(dirname "$0")/config.sh"
cd "$WORK"
curl -fsS -o icefiles.parquet.tmp "$CATALOG_URL" && mv icefiles.parquet.tmp icefiles.parquet
$RUN Rscript - <<'R'
f <- arrow::read_parquet("icefiles.parquet")
d <- as.Date(f$date)
stopifnot(!anyNA(d), !anyDuplicated(d), all(c("dsn", "array", "index") %in% names(f)))
dd <- as.integer(diff(sort(d)))
cat(sprintf("%i dates, %s .. %s; steps: %s\n", nrow(f), min(d), max(d),
            paste(names(table(dd)), table(dd), sep = "x", collapse = " ")))
gap <- which(dd > 1)
if (length(gap)) cat("gaps after:", format(sort(d)[gap]), "\n")
R
