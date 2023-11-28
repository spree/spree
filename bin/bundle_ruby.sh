#!/bin/sh

set -euxo pipefail

sudo apt-get update && sudo apt-get install libvips42
bundle check || bundle install
./bin/build-ci.rb install
