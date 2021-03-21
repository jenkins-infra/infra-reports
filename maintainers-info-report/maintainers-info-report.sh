#!/bin/bash

set -o nounset
set -o errexit
set -o pipefail

wget -q -O jq https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux64 || { echo "Failed to download jq" >&2 ; exit 1 ; }
chmod +x jq || { echo "Failed to make jq executable" >&2 ; exit 1 ; }

LIST_URL='https://reports.jenkins.io/maintainers.index.json'
echo "Querying URL: $LIST_URL" >&2
curl --silent --fail -u "$JIRA_AUTH" "$LIST_URL" > maintainers.index.json

declare -a MAINTAINERS_LIST
output="$( ./jq --raw-output '.[][]' maintainers.index.json | sort -u )" # Despite INFRA-2924 we can use raw because maintainers cannot have spaces per RPU
readarray -t MAINTAINERS_LIST <<< "$output"

echo '' > jira-users-list-tmp.json # clear file from any previous executions
for USERNAME in "${MAINTAINERS_LIST[@]}" ; do

  URL="https://issues.jenkins.io/rest/api/2/user?username=$USERNAME"
  echo "Querying URL: $URL" >&2
  curl --silent --fail -u "$JIRA_AUTH" "$URL" > jira-user-tmp.json

  ./jq '{ name, displayName }' jira-user-tmp.json >> jira-users-list-tmp.json
done

./jq --slurp '.' jira-users-list-tmp.json
