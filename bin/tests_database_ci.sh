#!/bin/sh

set -euxo pipefail

bundle install
./bin/build-ci.rb install
./bin/build-ci.rb test 
