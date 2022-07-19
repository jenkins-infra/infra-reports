#!/bin/bash

set -o nounset
set -o errexit

curl -X GET -H 'Content-Length: 0' -u "${ARTIFACTORY_AUTH}" "https://repo.jenkins-ci.org/api/security/users" > artifactory-users-raw.json
jq 'map(select(.realm | test("ldap"))) | [ .[].name ] | sort' artifactory-users-raw.json
