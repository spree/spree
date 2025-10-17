#!/bin/sh

set -eux

license_finder ignored_groups add development
license_finder ignored_groups add test

license_finder ignored_dependencies add spree_admin
license_finder ignored_dependencies add spree_storefront
license_finder ignored_dependencies add spree_api
license_finder ignored_dependencies add spree_core
license_finder ignored_dependencies add spree_emails
license_finder ignored_dependencies add spree_sample
license_finder ignored_dependencies add spree_cli

license_finder report --use-spdx-id --format json --aggregate-paths='admin' 'api' 'core' 'storefront' 'emails' --save=licenses.json

