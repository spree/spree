#!/bin/bash
# Used to create a sandbox Rails application for testing Spree locally

set -e

# Change to the spree root directory if we're not already there
cd "$(dirname "$0")/.."

echo "Creating Spree sandbox application..."

RAILS_VERSION="${RAILS_VERSION:-8.1.1}" ./install.sh --app-name=sandbox --verbose --auto-accept --local --force
rm -rf sandbox/.git
