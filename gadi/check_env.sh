#!/bin/bash
## Check the image has what trend.ice needs on Gadi (login node is fine):
##   bash gadi/check_env.sh
source "$(dirname "$0")/env.sh"
echo "image: $SIF"; ls -l "$SIF"
$RUN python3 - <<'PY'
import importlib
for m in ["numpy", "pyarrow", "fsspec", "xarray", "zarr", "pandas", "fastparquet", "kerchunk", "h5py", "h5netcdf", "icechunk"]:
    try:
        mod = importlib.import_module(m); print(f"  ok   {m} {getattr(mod, '__version__', '')}")
    except Exception as e:
        print(f"  MISS {m}: {e.__class__.__name__}")
PY
$RUN Rscript -e 'for (p in c("terra", "vapour", "gdalraster", "arrow")) cat(if (requireNamespace(p, quietly = TRUE)) "  ok  " else "  MISS", p, "\n")'
$RUN gdalinfo --version
