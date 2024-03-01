#!/bin/bash

set -o nounset
set -o errexit
set -x

: "${INSTANCE_NAME?}" "${INSTANCE_TOKEN?}" "${REPORT_NAME?}"

command -v "jq" >/dev/null || { echo "[ERROR] no 'jq' command found."; exit 1; }

function urlencode() {
    encoded=$(jq --raw-output --null-input --arg x "$1" '$x|@uri')
    echo "${encoded}"
}

version=${VERSION:-v1}
lastUpdate=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

jobFields="fullDisplayName,url,color,labelExpression"
queueFields="blocked,stuck,why,inQueueSince,buildableStartMilliseconds"
buildFields="fullDisplayName,url,result,timestamp,duration,estimatedDuration,inProgress,builtOn"

# Traverse and retrieve all jobs and their last build
jobsQuery="jobs[${jobFields},builds[${buildFields}]{0},jobs[${jobFields},builds[${buildFields}]{0},jobs[${jobFields},builds[${buildFields}]{0},jobs[${jobFields},builds[${buildFields}]{0}]]]]"
# Retrieve job(s) and their last build (if any) from queue
queueQuery="items[${queueFields},task[${jobFields},builds[${buildFields}]{0}]]"

jobsQueryUrl="https://${INSTANCE_NAME}/api/json?tree=$(urlencode "${jobsQuery}")"
queueQueryUrl="https://${INSTANCE_NAME}/queue/api/json?tree=$(urlencode "${queueQuery}")"

# Query the instance and flatten the results
jobsJSON=$(curl --user "${INSTANCE_TOKEN}" --request GET --location "${jobsQueryUrl}" | jq '.. | select(.color?)' | jq --slurp '.')
queueJSON=$(curl --user "${INSTANCE_TOKEN}" --request GET --location "${queueQueryUrl}" | jq '.. | select(.why?)' | jq --slurp '.')

# Initialise output with jobs JSON as it can be too big to be passed as argjson to jq(1)
json="{\"jobs\": ${jobsJSON}}"
# Add current date and API version to the instance jobs and queue
json=$(echo "${json}" | jq \
        --argjson queue "${queueJSON}" \
        --arg jobsQueryUrl "${jobsQueryUrl}" \
        --arg queueQueryUrl "${queueQueryUrl}" \
        --arg lastUpdate "${lastUpdate}" \
        --arg version "${version}" \
        '. += {"queue": $queue, "jobsQueryUrl": $jobsQueryUrl, "queueQueryUrl": $queueQueryUrl, "lastUpdate": $lastUpdate, "version": $version}')

echo "${json}" > "${REPORT_NAME}"
