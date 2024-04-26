#!/usr/bin/env bash
set -euxo pipefail

#
# MIT License
#
# Copyright (c) 2024 Jenkins Infra
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#

## Check for requirements
for cli in curl jq mkdir cp
do
    command -v "${cli}" || { echo "ERROR: command $cli is missing. Exiting."; exit 1; }
done

: "${REPORTS_FOLDER?Environment variable 'REPORTS_FOLDER' unset}"
: "${ETAGS_FILE?Environment variable 'REPORTS_FOLDER' unset}"
: "${REPORT_FILE?Environment variable 'REPORTS_FOLDER' unset}"
: "${PHS_API_URL?Environment variable 'PHS_API_URL' unset}"

# Pre-check for etags
curl --location --silent --show-error --remote-name "https://reports.jenkins.io/${REPORTS_FOLDER}/${ETAGS_FILE}" || echo "No previous etags file."

###
# using --compact-output to reduce output file by half.
# adding report generation date in 'lastUpdate' key of the report.
###
curl --etag-compare "${ETAGS_FILE}" \
    --etag-save "${ETAGS_FILE}" \
    --location --fail --silent --show-error "${PHS_API_URL}" \
    | jq --compact-output '. + { lastUpdate: (now | todate) }' > "${REPORT_FILE}"

mkdir -p "${REPORTS_FOLDER}"
cp "${REPORT_FILE}" "${ETAGS_FILE}" "${REPORTS_FOLDER}/"
