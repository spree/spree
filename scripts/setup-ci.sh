#!/usr/bin/env bash

path=$1
workdir=$(realpath ..)

mv "/opt/spree/$path/.bundle"    .
mv "/opt/spree/$path/spec/dummy" spec
mv /opt/spree/vendor             "$workdir"

bundle --path "$workdir/vendor/bundle"
