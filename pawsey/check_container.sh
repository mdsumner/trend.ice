#!/bin/bash
## does the container (plus the trend.ice R library) do everything the
## sea ice deployment needs? On a login node, from the repo root:
##   bash pawsey/check_container.sh
## Each line prints OK or FAIL; paste the lot back.
source "$(dirname "$0")/config.sh"
echo "RUN=$RUN"; echo "R_LIBS_USER=$R_LIBS_USER"
t() { local lab=$1; shift; if out=$("$@" 2>&1); then echo "OK   $lab: $(echo "$out" | tail -1)"; else echo "FAIL $lab: $(echo "$out" | tail -3 | tr '\n' ' ')"; fi; }
VRT=/vsicurl/https://data.source.coop/ausantarctic/ausantarctic-scratch/seaice/g02202-v6-daily-south/mdim.vrt
t "singularity"        $RUN true
t "R + libpaths"       $RUN Rscript -e 'cat(.libPaths(), sep=" | ")'
t "arrow then grist"   $RUN Rscript -e 'library(arrow); library(grist); cat("grist", format(packageVersion("grist")), "mdim:", exists("resolve_views", asNamespace("grist")))'
t "gdalraster mdim"    $RUN Rscript -e 'cat("gdalraster", format(packageVersion("gdalraster")), "GDAL", gdalraster::gdal_version()[1], exists("mdim_as_classic", asNamespace("gdalraster")))'
t "sf + jsonlite"      $RUN Rscript -e 'library(sf); library(jsonlite); cat("ok")'
t "mdim info (array)"  $RUN Rscript -e "j <- jsonlite::fromJSON(gdalraster::mdim_info('$VRT', 'cdr_seaice_conc', cout = FALSE, pretty = FALSE)); cat(unlist(j\$dimensions))"
t "python mdim"        $RUN python3 -c "from osgeo import gdal; gdal.UseExceptions(); d=gdal.OpenEx('$VRT', gdal.OF_MULTIDIM_RASTER); a=d.GetRootGroup().OpenMDArray('cdr_seaice_conc'); print(gdal.__version__, [x.GetName() for x in a.GetDimensions()], [x.GetSize() for x in a.GetDimensions()])"
