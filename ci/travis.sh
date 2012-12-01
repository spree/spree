#!/usr/bin/env bash
vars=(${GEM//:/ })
ENGINE=${vars[0]}
export DB=${vars[1]}
cd ${ENGINE}
bundle exec rake test_app
export BUNDLE_GEMFILE="`pwd`/Gemfile"
bundle install --quiet
bundle exec rspec spec
