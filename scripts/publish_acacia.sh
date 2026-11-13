#!/usr/bin/env bash
## Publish trend.ice outputs made on Nectar to Acacia (the home for everything
## we create), with the AWS CLI and the pawsey1197 profile.
##   scripts/publish_acacia.sh ~/trend-ice-chl-v2 chl_dsr_v2
##   scripts/publish_acacia.sh ~/trend-ice-chl    chl_dsr_v1
## (the ice season COGs have their own scripts/publish.sh)
set -euo pipefail
SRC="$1"; NAME="$2"
aws --profile pawsey1197 --endpoint-url https://projects.pawsey.org.au \
  s3 sync "$SRC/" "s3://aad-derived/trend-ice/$NAME/"
aws --profile pawsey1197 --endpoint-url https://projects.pawsey.org.au \
  s3 ls "s3://aad-derived/trend-ice/$NAME/" | tail -3
