#!/bin/sh

set -euxo pipefail

sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 32EE5355A6BC6E42
sudo apt-get update && sudo apt-get install libvips42
bundle install
./bin/build-ci.rb install
./bin/build-ci.rb test 
