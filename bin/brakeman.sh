#!/bin/sh

set -euxo pipefail

bundle exec brakeman -p api/ --exit-on-warn --exit-on-error
bundle exec brakeman -p core/ --exit-on-warn --exit-on-error
bundle exec brakeman -p storefront/ --exit-on-warn --exit-on-error
bundle exec brakeman -p admin/ --exit-on-warn --exit-on-error
bundle exec brakeman -p emails/ --exit-on-warn --exit-on-error