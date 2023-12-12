#!/bin/bash

set -o nounset
set -o errexit

curl -s -L --max-redirs 2 -X GET "https://updates.jenkins.io/latest/jenkins.war?mirrorlist" | grep "jenkins/war" | xq -q "a" > mirrorbits-mirrors-list-raw.txt
