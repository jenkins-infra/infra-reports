#!/bin/bash

set -o nounset
set -o errexit
set -x

command -v "jq" >/dev/null || { echo "[ERROR] no 'jq' command found."; exit 1; }
command -v "xq" >/dev/null || { echo "[ERROR] no 'xq' command found."; exit 1; }
command -v "dig" >/dev/null || { echo "[ERROR] no 'dig' command found."; exit 1; }

version=${VERSION:-v1}
reportName=${REPORT_NAME:-index.json}

# Note: this URL redirects to get.jenkins.io URL including last Jenkins version
# Ex: https://get.jenkins.io/war/2.442/jenkins.war?mirrorlist
source="https://updates.jenkins.io/latest/jenkins.war?mirrorlist"
lastUpdate=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

mirrorRowXPath="//table/tbody/tr"
nameXPath="//td[2]"
urlXPath="//td[3]"
countryXPath="//td[4]"
continentXPath="//td[5]"

mirrorRows=$(curl --silent --max-redirs 2 --request GET --location "${source}" | xq --node --xpath "${mirrorRowXPath}")

readarray -t names <<< "$(echo "${mirrorRows}" | xq --xpath "${nameXPath}" || true)"
readarray -t urls <<< "$(echo "${mirrorRows}" | xq --xpath "${urlXPath}" || true)"
readarray -t countries <<< "$(echo "${mirrorRows}" | xq --xpath "${countryXPath}" || true)"
readarray -t continents <<< "$(echo "${mirrorRows}" | xq --xpath "${continentXPath}" || true)"

json='{"mirrors": []}'
for ((i=0; i<${#names[@]}; i++)); do
    hostname=$(echo "${urls[i]}" | cut -d'/' -f3 | cut -d':' -f1)
    # As dig(1) can returns CNAME values, we need to filter IPs from its result(s) (those not finishing by a ".")
    ipv4=$(dig +short "${hostname}" A | jq --raw-input --slurp 'split("\n") | map(select(test("\\.$") | not)) | map(select(length > 0))')
    ipv6=$(dig +short "${hostname}" AAAA | jq --raw-input --slurp 'split("\n") | map(select(test("\\.$") | not)) | map(select(length > 0))')
    json=$(echo "${json}" | jq \
        --arg name "${names[i]}" \
        --arg url "${urls[i]}" \
        --argjson ipv4 "${ipv4}" \
        --argjson ipv6 "${ipv6}" \
        --arg country "${countries[i]}" \
        --arg continent "${continents[i]}" \
        '.mirrors |= . + [{"name": $name, "url": $url, "ipv4": $ipv4, "ipv6": $ipv6, "country": $country, "continent": $continent}]')
done

# Add current date and API version
json=$(echo "${json}" | jq \
        --arg lastUpdate "${lastUpdate}" \
        --arg version "${version}" \
        '. += {"lastUpdate": $lastUpdate, "version": $version}')

# Update the "get.jenkins.io" section of the existing report before returning it
result=$(cat "${reportName}" | jq \
        --argjson json "${json}" \
        '."get.jenkins.io" |=  $json')

echo "${result}" > "${reportName}"
