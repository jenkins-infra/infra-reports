#!/bin/bash

set -o nounset
set -o errexit

command -v "jq" >/dev/null || { echo "[ERROR] no 'jq' command found."; exit 1; }
command -v "xq" >/dev/null || { echo "[ERROR] no 'xq' command found."; exit 1; }

version=${VERSION:-v1}
reportPath=${REPORT_PATH:-infrastructure/v1/index.json}

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
    # As dig(1) can returns CNAME values, we need to filter IPs from its result(s)
    ip=$(dig +short "${hostname}" | jq --raw-input --slurp 'split("\n") | map(select(test("\\b(?:\\d{1,3}\\.){3}\\d{1,3}\\b")))')
    json=$(echo "${json}" | jq \
        --arg name "${names[i]}" \
        --arg url "${urls[i]}" \
        --argjson ip "${ip}" \
        --arg country "${countries[i]}" \
        --arg continent "${continents[i]}" \
        '.mirrors |= . + [{"name": $name, "url": $url, "ip": $ip, "country": $country, "continent": $continent}]')
done

# Add current date and API version
json=$(echo "${json}" | jq \
        --arg lastUpdate "${lastUpdate}" \
        --arg version "${version}" \
        '. += {"lastUpdate": $lastUpdate, "version": $version}')

# Retrieve existing report if it exists, empty object otherwise
reportUrl="https://reports.jenkins.io/${reportPath}"
existing=$(curl --silent --fail --max-redirs 2 --request GET --location "${reportUrl}" || echo '{}')

# Update the "get.jenkins.io" section of the existing report before returning it
result=$(echo "${existing}" | jq \
        --argjson json "${json}" \
        '."get.jenkins.io" |=  $json')

echo "${result}"
