#!/bin/bash

set -o nounset
set -o errexit

command -v "jq" >/dev/null || { echo "[ERROR] no 'jq' command found."; exit 1; }
command -v "xq" >/dev/null || { echo "[ERROR] no 'xq' command found."; exit 1; }

version=${VERSION:-v1}

# Redirect to get.jenkins.io URL including last Jenkins version
source="https://updates.jenkins.io/latest/jenkins.war?mirrorlist"
mirrorRowXPath="//table/tbody/tr"

nameXPath="//td[2]"
urlXPath="//td[3]"
countryXPath="//td[4]"
continentXPath="//td[5]"

mirrorRows=$(curl --silent --max-redirs 2 --request GET --location "${source}" | xq --node --xpath "${mirrorRowXPath}")

names=()
while read -r line; do
   names+=("${line}")
done <<< "$(echo "${mirrorRows}" | xq --xpath "${nameXPath}" || true)"

urls=()
while read -r line; do
   urls+=("${line}")
done <<< "$(echo "${mirrorRows}" | xq --xpath "${urlXPath}" || true)"

countries=()
while read -r line; do
   countries+=("${line}")
done <<< "$(echo "${mirrorRows}" | xq --xpath "${countryXPath}" || true)"

continents=()
while read -r line; do
   continents+=("${line}")
done <<< "$(echo "${mirrorRows}" | xq --xpath "${continentXPath}" || true)"

json='{"get.jenkins.io": {"mirrors": []}}'
for ((i=0; i<${#names[@]}; i++)); do
    json=$(echo "${json}" | jq \
        --arg name "${names[i]}" \
        --arg url "${urls[i]}" \
        --arg country "${countries[i]}" \
        --arg continent "${continents[i]}" \
        '."get.jenkins.io".mirrors |= . + [{"name": $name, "url": $url, "country": $country, "continent": $continent}]')
done

# Add last update date and API current version
json=$(echo "${json}" | jq \
        --arg lastUpdate "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
        --arg version "${version}" \
        '. += {"lastUpdate": $lastUpdate, "version": $version}')

echo "${json}"
