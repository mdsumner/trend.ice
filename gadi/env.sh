## Common settings, sourced by the other gadi/ scripts.
module load singularity
SIF=${SIF:-/g/data/jk72/mds581/sif_lib/gdal-r-python-extras_latest.sif}
## bind /g/data explicitly so BRAN (gb6) and our project space are visible
RUN="singularity exec -B /g/data $SIF"
