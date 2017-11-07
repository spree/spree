#!/bin/bash
# Spree commit backporter version 0.1
# Author: Bartosz Bonisławski (http://github.com/bbonislawski)

# This script automaticly cherry-picks commit specified as first param, creates branch with name specified in
# second param prefixed with proper version and then creates pull request to spree/spree
# It requires hub to http://hub.github.com to work

COMMIT=$1
BRANCH_NAME=$2
VERSIONS_ARRAY=(3-4)

for version in "${VERSIONS_ARRAY[@]}"
do
  git checkout "$version-stable"

  #creates new branch with correct name
  git checkout -b "$version/$BRANCH_NAME"

  git cherry-pick $COMMIT

  git push -u origin "$version/$BRANCH_NAME"

  #creates pull request with message from cherry-picked commit
  hub pull-request -b spree/spree:$version-stable -m "Backport ($version) $(git log -1 --pretty=%B)"
done
