#!/bin/bash

set -o nounset
set -o errexit
set -x

command -v "jq" >/dev/null || { echo "[ERROR] no 'jq' command found."; exit 1; }
command -v "xq" >/dev/null || { echo "[ERROR] no 'xq' command found."; exit 1; }
command -v "dig" >/dev/null || { echo "[ERROR] no 'dig' command found."; exit 1; }

version=${VERSION:-v1}
reportName=${REPORT_NAME:-index.json}
sourceHTML=${SOURCE_HTML:-source.html}
source="https://get.jenkins.io/index.html?mirrorstats"
lastUpdate=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

mirrorTableQuery="body > div > div > div > table"
mirrorRowXPath="//table/tbody/tr"
cellXPath="//td[@rowspan=2]"
fallback="archives.jenkins.io"

# Retrieve the source HTML into $sourceHTML file
curl --silent --max-redirs 2 --request GET --location "${source}" --output "${sourceHTML}"

# Retrieving all rows of the table containing all mirrors
mirrorRows=$(xq --node --query "${mirrorTableQuery}" < "${sourceHTML}" \
    | xq --node --xpath "${mirrorRowXPath}")

if [[ -z ${mirrorRows} ]]; then
    echo "Error: no mirror returned from ${source}"
    exit 1
fi

# Keep only cells not finishing by " ago" (last update column) and that are not the fallback mirror
readarray -t hostnames <<< "$(echo "${mirrorRows}" | xq --xpath "${cellXPath}" | grep -v ' ago' | grep -v "${fallback}" || true)"

json='{"mirrors": []}'
for ((i=0; i<${#hostnames[@]}; i++)); do
    hostname="${hostnames[i]}"
    # As dig(1) can returns CNAME values, we need to filter IPs from its result(s) (those not finishing by a ".")
    ipv4=$(dig +short "${hostname}" A | jq --raw-input --slurp 'split("\n") | map(select(test("\\.$") | not)) | map(select(length > 0))')
    ipv6=$(dig +short "${hostname}" AAAA | jq --raw-input --slurp 'split("\n") | map(select(test("\\.$") | not)) | map(select(length > 0))')
    json=$(echo "${json}" | jq \
        --arg hostname "${hostnames[i]}" \
        --argjson ipv4 "${ipv4}" \
        --argjson ipv6 "${ipv6}" \
        '.mirrors |= . + [{"hostname": $hostname, "ipv4": $ipv4, "ipv6": $ipv6}]')
done

if [[ ${i} -eq 0 ]]; then
    echo "Error: no mirror returned from ${source}"
    exit 1
fi

# Add current date and API version
json=$(echo "${json}" | jq \
        --arg lastUpdate "${lastUpdate}" \
        --arg version "${version}" \
        '. += {"lastUpdate": $lastUpdate, "version": $version}')

# Update the "get.jenkins.io" section of the existing report before returning it
result=$(jq --argjson json "${json}" '."get.jenkins.io" |=  $json' < "${reportName}")

echo "${result}" > "${reportName}"
