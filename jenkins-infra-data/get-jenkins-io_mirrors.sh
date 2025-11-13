#!/bin/bash

set -o nounset
set -o errexit
set -o pipefail
set -x

command -v 'jq' >/dev/null || { echo "[ERROR] no 'jq' command found."; exit 1; }
command -v 'xq' >/dev/null || { echo "[ERROR] no 'xq' command found."; exit 1; }
command -v 'dig' >/dev/null || { echo "[ERROR] no 'dig' command found."; exit 1; }

test -d "${DIST_DIR}"

mirrorsSource='https://get.jenkins.io/index.html?mirrorstats'
mirrorTableQuery='body > div > div > div > table'
mirrorRowXPath='//table/tbody/tr'
cellXPath='//td[@rowspan=2]'
fallback='archives.jenkins.io'

# Retrieve the source HTML
sourceHTML="$(curl --silent --show-error --location "${mirrorsSource}")"

# Retrieving all rows of the table containing all mirrors
mirrorRows="$(echo "${sourceHTML}" \
    | xq --node --query "${mirrorTableQuery}" \
    | xq --node --xpath "${mirrorRowXPath}"\
)"

if [[ -z "${mirrorRows}" ]]; then
    echo "Error: no mirror returned from ${mirrorsSource}"
    exit 1
fi

# Retrieve list of hostnames, one per line. Keep only cells not finishing by " ago" (last update column) and that are not the fallback mirror.
hostnames="$(echo "${mirrorRows}" | xq --xpath "${cellXPath}" | grep -v ' ago' | grep -v "${fallback}")"
additional_data="$(cd "$(dirname "$0")" && pwd -P)/get-jenkins-io-data.json"

json='{"mirrors": []}'
while IFS= read -r hostname
do
    # As dig(1) can returns CNAME values, we need to filter IPs from its result(s) (those not finishing by a ".")
    ipv4="$(dig +short "${hostname}" A | jq --raw-input --slurp 'split("\n") | map(select(test("\\.$") | not)) | map(select(length > 0))')"
    ipv6="$(dig +short "${hostname}" AAAA | jq --raw-input --slurp 'split("\n") | map(select(test("\\.$") | not)) | map(select(length > 0))')"
    outbound_ipv4="$(jq --raw-output ".mirrors.\"${hostname}\".outbound_ipv4" "${additional_data}")"
    # Assume the same in and out IPv4s set if not specified in the additional data file
    if [ "${outbound_ipv4}" == "null" ]
    then
        outbound_ipv4="$ipv4"
    fi
    outbound_ipv6="$(jq --raw-output ".mirrors.\"${hostname}\".outbound_ipv6" "${additional_data}")"
    # Assume the same in and out IPv6s set if not specified in the additional data file
    if [ "${outbound_ipv6}" == "null" ]
    then
        outbound_ipv6="$ipv6"
    fi
    json="$(echo "${json}" | jq \
        --arg hostname "${hostname}" \
        --argjson ipv4 "${ipv4}" \
        --argjson ipv6 "${ipv6}" \
        --argjson outbound_ipv4 "${outbound_ipv4}" \
        --argjson outbound_ipv6 "${outbound_ipv6}" \
        '.mirrors |= . + [{"hostname": $hostname, "ipv4": $ipv4, "ipv6": $ipv6, "outbound_ipv4": $outbound_ipv4, "outbound_ipv6": $outbound_ipv6}]')"
done <<< "${hostnames}"

if [[ "${json}" == '{"mirrors": []}' ]]; then
    echo "Error: no mirror returned from ${mirrorsSource}"
    exit 1
fi

## Provide outbound IPs for mirror providers to add in their allow-list for scanning

# publick8s hosts the mirrorbits services which emit outbound requests to scan external mirrors
publick8sIpv4List="$(curl --silent --show-error --location 'https://reports.jenkins.io/jenkins-infra-data-reports/azure.json' \
    | jq '.["publick8s"].lb_outbound_ips.ipv4' \
)"
# infra.ci.jenkins.io (controller and agents) may emit outbound requests to external mirrors for testing or setup purposes
infraciIpv4List="$(curl --silent --show-error --location 'https://reports.jenkins.io/jenkins-infra-data-reports/azure-net.json' \
    | jq '.["infra.ci.jenkins.io"].outbound_ips' \
)"
json="$(echo "${json}" | jq \
    --argjson publick8sIpv4List "${publick8sIpv4List}" \
    --argjson infraciIpv4List "${infraciIpv4List}" \
    '. += {"outbound_ips": ([$publick8sIpv4List + $infraciIpv4List] | flatten | unique)}' \
)"

echo "${json}"
exit 0
