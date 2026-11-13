#!/bin/bash
## one-off: install grist (mdim-projected branch) into the trend.ice R
## library, fetch the S2 registry (shared with trend.sst) and the catalog,
## build the pixel -> cell mapping for the 316 x 332 polar grid.
##   bash pawsey/setup.sh     (login node is fine: the mapping takes seconds)
set -eu
source "$(dirname "$0")/config.sh"
mkdir -p "$ICE_LIB"
$RUN Rscript -e "remotes::install_github('$GRIST_REF', lib = Sys.getenv('ICE_LIB'), upgrade = 'never', force = TRUE)"
bash "$REPO/pawsey/catalog.sh"
cd "$WORK"
## the registry is trend.sst's (committed there); a clone beside this repo
## or its Acacia copy
if [ ! -f s2_registry.parquet ]; then
  if [ -f "$REPO/../trend.sst/s2_registry.parquet" ]; then cp "$REPO/../trend.sst/s2_registry.parquet" .
  else curl -fsS -o s2_registry.parquet "$REGISTRY_URL"; fi
fi
$RUN Rscript - <<'R'
library(arrow); library(grist)
reg <- read_parquet("s2_registry.parquet")
files <- read_parquet("icefiles.parquet")
src <- stat_source(Sys.getenv("SRC"), files, transform = Sys.getenv("TRANSFORM"),
                   grid = list(projection = Sys.getenv("CRS")))
str(src$grid)
stopifnot(src$shape == "mdim", isTRUE(src$grid$projected),
          identical(src$grid$dimension, c(316L, 332L)))
build_mapping(src, reg)
R
