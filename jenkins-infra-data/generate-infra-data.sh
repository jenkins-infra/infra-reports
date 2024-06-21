#!/bin/bash
# generate-infra-data.sh: Generate a JSON report named $1 in the directory $2 (with a optional version $3).
#  Note: This script orchestrate generation by "parts": there are sub-scripts per services which generate partial content.

set -o nounset
set -o errexit
set -o pipefail
set -x

REPORT_NAME="$1"
test -n "${REPORT_NAME}"
DIST_DIR="${2%/}"
test -n "${DIST_DIR}"
mkdir -p "${DIST_DIR}"
# Sub scripts need this
export DIST_DIR
VERSION="${3:-v1}"

command -v "date" >/dev/null || { echo "[ERROR] no 'jq' command found."; exit 1; }
command -v "jq" >/dev/null || { echo "[ERROR] no 'jq' command found."; exit 1; }

json='{}'

## get.jenkins.io
# BSD Date and GNU Date have the same behavior with this pattern
lastUpdate="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
getJenkinsIoData="$(./get-jenkins-io_mirrors.sh)"
# Add current date and API version
getJenkinsIoData="$(echo "${getJenkinsIoData}" | jq --compact-output \
  --arg lastUpdate "${lastUpdate}" \
  --arg version "${VERSION}" \
  '. += {"lastUpdate": $lastUpdate, "version": $version}')"
echo "${json}"
json="$(echo "${json}" | jq --compact-output \
  --argjson getJenkinsIoData "${getJenkinsIoData}" \
  '. + {"get.jenkins.io": $getJenkinsIoData}' \
)"

## Write report
echo "${json}" > "${DIST_DIR}/${REPORT_NAME}"
