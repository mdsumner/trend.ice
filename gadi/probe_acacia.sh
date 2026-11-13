#!/bin/bash
## Probe Acacia write access from Gadi with the pawsey1197 profile:
## write a tiny file, list it, read it back, delete it.
##   bash gadi/probe_acacia.sh          (login node is fine: it has network)
source "$(dirname "$0")/env.sh"
unset AWS_NO_SIGN_REQUEST
export AWS_PROFILE=${AWS_PROFILE:-pawsey1197}
export AWS_S3_ENDPOINT=projects.pawsey.org.au
export AWS_VIRTUAL_HOSTING=NO
P=/vsis3/aad-derived/trend-ice/_probe
f=$(mktemp -p "$HOME" probe.XXXXXX)
echo "trend.ice probe $(hostname) $(date -Is)" > "$f"
echo "profile $AWS_PROFILE; credentials file: $(ls ~/.aws/credentials 2>/dev/null || echo MISSING)"
echo "== write";  $RUN gdal vsi copy "$f" "$P/probe.txt" && echo ok
echo "== list";   $RUN gdal vsi list "$P/"
echo "== read";   $RUN gdal vsi copy "$P/probe.txt" /vsistdout/ 2>/dev/null || $RUN cat "/vsis3/aad-derived/trend-ice/_probe/probe.txt" 2>/dev/null
echo "== delete"; $RUN gdal vsi delete "$P/probe.txt" && echo ok
rm -f "$f"
