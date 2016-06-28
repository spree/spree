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
current_branch = '$(git symbolic-ref --short -q HEAD)'
gem 'spree', path: '..', branch: current_branch
gem 'spree_auth_devise', github: 'spree/spree_auth_devise', branch: current_branch

group :test, :development do
  gem 'bullet'
  gem 'pry-byebug'
  gem 'rack-mini-profiler'
end
RUBY

bundle install --gemfile Gemfile
bundle exec rails g spree:install --auto-accept --user_class=Spree::User --enforce_available_locales=true
bundle exec rails g spree:auth:install
