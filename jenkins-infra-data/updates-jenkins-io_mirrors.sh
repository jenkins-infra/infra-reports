#!/bin/bash

set -o nounset
set -o errexit
set -o pipefail
set -x

command -v 'jq' >/dev/null || { echo "[ERROR] no 'jq' command found."; exit 1; }
command -v 'xq' >/dev/null || { echo "[ERROR] no 'xq' command found."; exit 1; }
command -v 'dig' >/dev/null || { echo "[ERROR] no 'dig' command found."; exit 1; }

test -d "${DIST_DIR}"

mirrorsSource="https://mirrors.updates.jenkins.io/current/update-center.json?mirrorlist"
mirrorTableQuery='body > div > div > div > table'
mirrorRowXPath='//table/tbody/tr'
cellXPath='//td[2]'
fallback='archives.jenkins.io'
updateCenterHostname=updates.jenkins.io

function getIPsFromHostname() {
    dig +short "${1}" "${2}" | jq --raw-input --slurp 'split("\n") | map(select(test("\\.$") | not)) | map(select(length > 0))'
    return
}

# Retrieve the source HTML
sourceHTML="$(curl --silent --show-error --location "${mirrorsSource}")"

# Retrieving all rows of the table containing all mirrors
mirrorRows="$(echo "${sourceHTML}" \
    | xq --node --query "${mirrorTableQuery}" \
    | xq --node --xpath "${mirrorRowXPath}" \
)"

if [[ -z "${mirrorRows}" ]]; then
    echo "Error: no mirror returned from ${mirrorsSource}"
    exit 1
fi

# Retrieve a list of hostname, one per line. Keep only cells not finishing by " ago" (last update column) and that are not the fallback mirror.
mirrorshostnames="$(echo "${mirrorRows}" | xq --xpath "${cellXPath}" | grep -v ' ago' | grep -v "${fallback}")"

json='{"servers": []}'
while IFS= read -r mirrorHostname
do
    # As dig(1) can returns CNAME values, we need to filter IPs from its result(s) (those not finishing by a ".")
    ipv4="$(getIPsFromHostname "${mirrorHostname}" 'A')"
    ipv6="$(getIPsFromHostname "${mirrorHostname}" 'AAAA')"
    json="$(echo "${json}" | jq \
        --arg hostname "${mirrorHostname}" \
        --argjson ipv4 "${ipv4}" \
        --argjson ipv6 "${ipv6}" \
        '.servers |= . + [{"hostname": $hostname, "ipv4": $ipv4, "ipv6": $ipv6}]')"

done <<< "${mirrorshostnames}"

if [[ "${json}" == '{"mirrors": []}' ]]; then
    echo "Error: no mirror returned from ${mirrorsSource}"
    exit 1
fi


updateCenterIpv4="$(getIPsFromHostname "${updateCenterHostname}" 'A')"
updateCenterIpv6="$(getIPsFromHostname "${updateCenterHostname}" 'AAAA')"

json="$(echo "${json}" | jq \
    --arg hostname "${updateCenterHostname}" \
    --argjson ipv4 "${updateCenterIpv4}" \
    --argjson ipv6 "${updateCenterIpv6}" \
    '.servers |= . + [{"hostname": $hostname, "ipv4": $ipv4, "ipv6": $ipv6}]')"

echo "${json}"
exit 0
