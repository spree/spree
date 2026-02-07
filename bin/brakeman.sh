#!/bin/sh

set -eux

bundle exec brakeman -p api/ --exit-on-warn --exit-on-error -o brakeman-api.html -o brakeman-api.json
bundle exec brakeman -p core/ --exit-on-warn --exit-on-error -o brakeman-core.html -o brakeman-core.json
bundle exec brakeman -p admin/ --exit-on-warn --exit-on-error -o brakeman-admin.html -o brakeman-admin.json
bundle exec brakeman -p emails/ --exit-on-warn --exit-on-error -o brakeman-emails.html -o brakeman-emails.json
