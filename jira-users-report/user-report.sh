#!/bin/bash

set -o nounset
set -o errexit
set -o pipefail

wget -q -O jq https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux64 || { echo "Failed to download jq" >&2 ; exit 1 ; }
chmod +x jq || { echo "Failed to make jq executable" >&2 ; exit 1 ; }

declare -a ALL_USERS

URL="https://issues.jenkins.io/rest/api/2/group/member?groupname=jira-users"
while true ; do
  echo "Querying URL: $URL" >&2
  curl --silent --fail -u "$JIRA_AUTH" "$URL" > jira-users-tmp.json

  output="$( ./jq '.values[] | .name' jira-users-tmp.json )" # Deliberately not raw because INFRA-2924
  readarray -t USERS <<< "$output"

  ALL_USERS+=( "${USERS[@]}" )

  done="$( ./jq --raw-output '.isLast' jira-users-tmp.json )"
  if [[ "$done" = "true" ]] ; then
    break
  fi

  # Next URL is part of the output
  URL="$( ./jq --raw-output '.nextPage' jira-users-tmp.json )"
done

echo "${ALL_USERS[@]}" | ./jq --slurp '.'
