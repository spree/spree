#!/bin/sh

set -euxo pipefail

if [$DB -eq "mysql"]
then
    sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 4EB27DB2A3B88B8B
fi

ls -l /tmp

sudo apt-get update && sudo apt-get install libvips42
bundle install
./bin/build-ci.rb install
./bin/build-ci.rb test 
