#!/bin/bash --login
#SBATCH --job-name=ice-onboard
#SBATCH --account=pawsey1362
#SBATCH --partition=work
#SBATCH --nodes=1 --ntasks=1 --cpus-per-task=4 --mem=16G
#SBATCH --time=01:00:00
#SBATCH --output=%x-%j.out
## onboarding in one job, from the repo root:
##   sbatch pawsey/onboard-ice.sh
## setup (grist branch, registry, catalog, mapping) -> oracle. Then read
## the GRIST and NUMPY lines in ice-onboard-<jobid>.out and LOOK at
## $WORK/oracle-2010-09-15.png before any backfill.
set -eu
cd "${SLURM_SUBMIT_DIR:-$PWD}"
bash pawsey/setup.sh
bash pawsey/oracle.sh
