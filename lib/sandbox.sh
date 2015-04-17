#!/bin/sh
# Used in the sandbox rake task in Rakefile

rm -rf ./sandbox
bundle exec rails new sandbox --skip-bundle
if [ ! -d "sandbox" ]; then
  echo 'sandbox rails application failed'
  exit 1
fi

cd ./sandbox

cat <<RUBY >> Gemfile
gem 'spree', path: '..'
gem 'spree_auth_devise', github: 'spree/spree_auth_devise', branch: '3-0-stable'

group :test, :development do
  gem 'bullet'
  gem 'pry-byebug'
  gem 'rack-mini-profiler'
end
RUBY

bundle install --gemfile Gemfile
bundle exec rails g spree:install --auto-accept --user_class=Spree::User --enforce_available_locales=true
bundle exec rails g spree:auth:install
