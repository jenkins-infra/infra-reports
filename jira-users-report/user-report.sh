#!/bin/bash

set -o nounset
set -o errexit
set -o pipefail

BASE_URL="https://issues.jenkins.io/rest/api/2/group/member"
PAGE_SIZE=50
PARALLELISM="${PARALLELISM:-10}"

TMPDIR="$(mktemp -d)"
trap 'rm -rf "${TMPDIR}"' EXIT

fetch_page() {
    local start_at="$1"
    local output
	output="${TMPDIR}/page-$(printf '%06d' "${start_at}").json"

    echo "Fetching page starting at ${start_at}" >&2

    curl --silent --fail -u "${JIRA_AUTH}" "${BASE_URL}?groupname=jira-users&maxResults=${PAGE_SIZE}&startAt=${start_at}" > "${output}"
}

process_page() {
    local start_at="$1"
    local input
    local output
	input="${TMPDIR}/page-$(printf '%06d' "${start_at}").json"
	output="${TMPDIR}/users-$(printf '%06d' "${start_at}").json"

    # Deliberately not using --raw because INFRA-2924.
    jq '.values[] | .name' "${input}" > "${output}"
}

export -f fetch_page
export BASE_URL PAGE_SIZE TMPDIR JIRA_AUTH

# Fetch the first page.
fetch_page 0

# The first page tells us how many pages we need
TOTAL="$(jq -r '.total' "${TMPDIR}/page-000000.json")"

echo "Found ${TOTAL} users" >&2

# Fetch the remaining pages concurrently
seq "${PAGE_SIZE}" "${PAGE_SIZE}" "$((TOTAL - 1))" |
    xargs -P "${PARALLELISM}" -n 1 bash -c 'fetch_page "$1"' _

# Extract users from each page in the original page order
for ((start_at = 0; start_at < TOTAL; start_at += PAGE_SIZE)); do
    process_page "${start_at}"
done

cat "${TMPDIR}"/users-*.json | jq --slurp '.'
