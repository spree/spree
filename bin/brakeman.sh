#!/bin/sh

set -eux

bundle exec brakeman -p api/ --exit-on-warn --exit-on-error -o brakeman-api.html
bundle exec brakeman -p core/ --exit-on-warn --exit-on-error -o brakeman-core.html
bundle exec brakeman -p storefront/ --exit-on-warn --exit-on-error -o brakeman-storefront.html
bundle exec brakeman -p admin/ --exit-on-warn --exit-on-error -o brakeman-admin.html
bundle exec brakeman -p emails/ --exit-on-warn --exit-on-error -o brakeman-emails.html