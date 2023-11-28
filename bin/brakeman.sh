#!/bin/sh

set -euxo pipefail

./bin/build-ci.rb install
bundle exec brakeman -p api/ --ignore-config api/brakeman.ignore --skip-files app/controllers/spree/api/v1/ --exit-on-warn --exit-on-error
bundle exec brakeman -p core/ --ignore-config core/brakeman.ignore --exit-on-warn --exit-on-error
