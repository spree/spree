#!/bin/sh
# Used in the sandbox rake task in Rakefile

set -e

case "$DB" in
mysql)
  RAILSDB="mysql"
  ;;
postgres|'')
  RAILSDB="postgresql"
  ;;
*)
  echo "Invalid DB specified: $DB"
  exit 1
  ;;
esac

rm -rf ./sandbox
bundle exec rails new sandbox --database="$RAILSDB" \
  --skip-bundle \
  --skip-git \
  --skip-keeps \
  --skip-rc \
  --skip-spring \
  --skip-test \
  --skip-coffee \
  --skip-javascript \
  --skip-bootsnap

if [ ! -d "sandbox" ]; then
  echo 'sandbox rails application failed'
  exit 1
fi

cd ./sandbox

# Gems listed below were tagged on 1 August 2022
if [ "$SPREE_AUTH_DEVISE_PATH" != "" ]; then
  SPREE_AUTH_DEVISE_GEM="gem 'spree_auth_devise', path: '$SPREE_AUTH_DEVISE_PATH'"
else
  # For now tag on branch main will be used,
  # in the future replace it with 4.5-stable release
  SPREE_AUTH_DEVISE_GEM="gem 'spree_auth_devise', github: 'spree/spree_auth_devise', tag: 'v4.5.0-development'"
fi

if [ "$SPREE_GATEWAY_PATH" != "" ]; then
  SPREE_GATEWAY_GEM="gem 'spree_gateway', path: '$SPREE_GATEWAY_PATH'"
else
  # spree_gateway 'main' branch has latest needed changes - this tag needs to be replaced after release of 4.5-stable
  SPREE_GATEWAY_GEM="gem 'spree_gateway', github: 'spree/spree_gateway', tag: 'v4.5.0-development'"
fi

if [ "$SPREE_DASHBOARD_PATH" != "" ]; then
  SPREE_BACKEND_GEM="gem 'spree_backend', path: '$SPREE_DASHBOARD_PATH'"
else
  # For now tag on branch main will be used to provide compatibility with Rails 7,
  # in the future replace it with 4.5-stable release
  SPREE_BACKEND_GEM="gem 'spree_backend', github: 'spree/spree_backend', tag: 'v4.5.0-development'"
fi

cat <<RUBY >> Gemfile
gem 'spree', path: '..'
gem 'spree_emails', path: '../emails'
gem 'spree_sample', path: '../sample'
$SPREE_BACKEND_GEM
$SPREE_AUTH_DEVISE_GEM
$SPREE_GATEWAY_GEM
gem 'spree_i18n', github: 'spree-contrib/spree_i18n', ref: '3c3e5954888232153a78fa4168f40b3255586b3b'

group :test, :development do
  gem 'bullet'
  gem 'pry-byebug'
  gem 'awesome_print'
end

# ExecJS runtime
gem 'mini_racer'

# temporary fix for sassc segfaults on ruby 3.0.0 on Mac OS Big Sur
# this change fixes the issue:
# https://github.com/sass/sassc-ruby/commit/04407faf6fbd400f1c9f72f752395e1dfa5865f7
gem 'sassc', github: 'sass/sassc-ruby', branch: 'master'

gem 'rack-cache'
gem 'oj'

gem 'jsbundling-rails'
RUBY

cat <<RUBY >> config/environments/development.rb
Rails.application.config.hosts.clear
RUBY

touch config/initializers/oj.rb

cat <<RUBY >> config/initializers/oj.rb
require 'oj'

Oj.optimize_rails
RUBY

touch config/initializers/bullet.rb

cat <<RUBY >> config/initializers/bullet.rb
if Rails.env.development? && defined?(Bullet)
  Bullet.enable = true
  Bullet.rails_logger = true
  Bullet.stacktrace_includes = [ 'spree_core', 'spree_frontend', 'spree_api', 'spree_backend', 'spree_emails' ]
end
RUBY

bundle update
bundle install --gemfile Gemfile

bin/rails javascript:install:esbuild
bin/rails turbo:install
yarn install

# for npm versions lower than 7.1 we need to add "build" script manually
# so below is added to ensure compatibility
cat <<RUBY > package.json
{
  "name": "app",
  "private": "true",
  "dependencies": {
    "@hotwired/turbo-rails": "^7.1.3",
    "@spree/dashboard": "^0.2.0",
    "esbuild": "^0.14.47"
  },
    "scripts": {
      "build": "esbuild app/javascript/*.* --bundle --sourcemap --outdir=app/assets/builds --public-path=assets"
    }
}
RUBY

bin/rails db:drop || true
bin/rails db:create
bin/rails g spree:install --auto-accept --user_class=Spree::User --sample=true
bin/rails g spree:backend:install
bin/rails g spree:emails:install
bin/rails g spree:auth:install
bin/rails g spree_gateway:install
yarn build
