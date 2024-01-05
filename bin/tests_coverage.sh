#!/bin/sh

set -euxo pipefail


mkdir -p tmp/
curl -L https://codeclimate.com/downloads/test-reporter/test-reporter-latest-linux-amd64 > ./tmp/cc-test-reporter
chmod +x ./tmp/cc-test-reporter

export GIT_BRANCH="$CIRCLE_BRANCH"
export GIT_COMMIT_SHA="$CIRCLE_SHA1"
export GIT_COMMITTED_AT="$(date +%s)"


./tmp/cc-test-reporter format-coverage -t simplecov -o tmp/codeclimate.api.json /tmp/workspace/simplecov/api/.resultset.json
./tmp/cc-test-reporter format-coverage -t simplecov -o tmp/codeclimate.core.json /tmp/workspace/simplecov/core/.resultset.json
./tmp/cc-test-reporter format-coverage -t simplecov -o tmp/codeclimate.emails.json /tmp/workspace/simplecov/emails/.resultset.json

./tmp/cc-test-reporter sum-coverage tmp/codeclimate.*.json -p 3 -o tmp/codeclimate.total.json
./tmp/cc-test-reporter upload-coverage -i tmp/codeclimate.total.json