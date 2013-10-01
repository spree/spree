#!/bin/sh
# Used in the sandbox rake task in Rakefile

rm -rf ./sandbox
bundle exec rails new sandbox --skip-bundle
if [ ! -d "sandbox" ]; then
  echo 'sandbox rails application failed'
  exit 1
fi

cd ./sandbox
echo "gem 'spree', :path => '..'" >> Gemfile
echo "gem 'spree_auth_devise', :github => 'spree/spree_auth_devise', :branch => '2-1-stable'" >> Gemfile

bundle install --gemfile Gemfile
bundle exec rails g spree:install --auto-accept --user_class=Spree::User
